import vibe.d;
import d2sqlite3;

//==============================================================================
// Models
//==============================================================================

enum State : byte
{
    unsaved,
    ok,
    error,
    unknown,
}

struct Check
{
    int id;
    string name, dataSource, query;
    float threshold;
    @byName State state;
    Subscriptions subscriptions;

private:
    string validate()
    {
        import std.math : isFinite;

        if (!name.length)
            return "name is empty";
        if (!dataSource.length)
            return "data source is empty";
        if (!query.length)
            return "query is empty";
        if (!isFinite(threshold))
            return "threshold must be finite";
        return null;
    }
}

struct Subscriptions
{
    string json;
    alias json this;

    Subscription[] toRepresentation() const
    {
        return deserializeJson!(Subscription[])(json);
    }

    static Subscriptions fromRepresentation(Subscription[] s)
    {
        return Subscriptions(serializeToJsonString(s));
    }
}

///==============================================================================
// ORM
//==============================================================================

template isNullable(T)
{
    enum isNullable = is(typeof(T.init.isNull) : bool)
            && is(typeof(T.init.nullify())) && is(typeof(T.init.get()));
}

template sqlType(T)
{
    static if (isNullable!T)
        enum sqlType = _sqlType!(_sqlRepr!(typeof(T.init.get())));
    else
        enum sqlType = _sqlType!(_sqlRepr!T) ~ " NOT NULL";
}

private template _sqlType(T)
{
    import std.traits;

    static if (isIntegral!T)
        enum _sqlType = "INT";
    else static if (isFloatingPoint!T)
        enum _sqlType = "REAL";
    else static if (isSomeString!T)
        enum _sqlType = "TEXT";
    else
        static assert(0, "Don't know how to map Type " ~ T.stringof ~ " to SQL.");
}

private template _sqlRepr(T)
{
    static if (is(T : string))
        alias _sqlRepr = string;
    else
        alias _sqlRepr = T;
}

string toUnderscore(string camelCase)
{
    import std.uni : isLower, isUpper, toLower;

    size_t pos;
    string ret;

    void appendPart(size_t end)
    {
        if (pos)
            ret ~= "_";
        ret ~= camelCase[pos .. end].toLower;
        pos = end;
    }

    foreach (i, c; camelCase[0 .. $ - 1])
    {
        if (isUpper(c) && isLower(camelCase[i + 1]))
            appendPart(i);
    }
    appendPart(camelCase.length);
    return ret;
}

unittest
{
    assert("User".toUnderscore == "user");
    assert("UserRole".toUnderscore == "user_role");
    assert("HTTPRequest".toUnderscore == "http_request");
}

struct Statements(T)
{
    this(Database db)
    {
        import std.algorithm.iteration : filter;
        import std.meta : staticMap;
        import std.range : zip;
        import std.string : toLower;
        import std.traits : Fields, FieldNameTuple;

        enum tableName = T.stringof.toUnderscore ~ "s";
        enum primaryKey = "id";
        enum primaryType = "INTEGER";
        enum columnNames = [FieldNameTuple!T].filter!(n => n != "id").map!toUnderscore.array;
        enum columnTypes = [staticMap!(sqlType, Fields!T[1 .. $])];

        enum createTable = "CREATE TABLE IF NOT EXISTS %1$s (%2$s %3$s PRIMARY KEY, %4$(%-(%s %), %))".format(
                tableName, primaryKey, primaryType,
                columnNames.zip(columnTypes).map!(tup => [tup[]]));
        db.execute(createTable);

        enum all = `SELECT * FROM "%1$s"`.format(tableName);
        enum find = `SELECT * FROM "%1$s" WHERE "%2$s" = :id`.format(tableName, primaryKey);
        enum insert = `INSERT INTO "%1$s" (%2$-("%s"%|, %)) VALUES (%2$-(:%s, %))`.format(
                tableName, columnNames);
        enum update = `UPDATE "%1$s" SET %2$-(%s, %) WHERE "%3$s" = :id`.format(
                tableName, columnNames.map!(n => `"%1$s" = :%1$s`.format(n)), primaryKey);
        enum remove = `DELETE FROM "%1$s" WHERE "%2$s" = :id`.format(tableName, primaryKey);

        _all = db.prepare(all);
        _find = db.prepare(find);
        _insert = db.prepare(insert);
        _update = db.prepare(update);
        _remove = db.prepare(remove);
        _db = db;
    }

    T[] all()
    {
        return exec!(rows => rows.map!(r => deserialize(r)).array)(_all);
    }

    T find(int _id)
    {
        return exec!(rows => deserialize(rows.front))(_find, _id);
    }

    void insert(ref T t)
    {
        exec(_insert, serialize(t.tupleof[1 .. $])[]);
        t.id = _db.lastInsertRowid.to!int;
    }

    void update(T t)
    {
        exec(_update, serialize(t.tupleof[1 .. $])[], t.id);
    }

    void remove(T t)
    {
        exec(_remove, t.id);
    }

private:

    static T deserialize(Row row)
    {
        T ret;
        deserialize(row, ret);
        return ret;
    }

    static void deserialize(Row row, ref T t)
    {
        import std.traits : Fields, FieldNameTuple;

        foreach (i, mem; FieldNameTuple!T)
        {
            alias FT = Fields!T[i];
            enum colName = mem.toUnderscore;

            static if (is(FT == struct))
                __traits(getMember, t, mem) = FT(row[colName].as!string);
            else
                __traits(getMember, t, mem) = row[colName].as!FT;
        }
    }

    static auto serialize(Args...)(auto ref Args args)
    {
        import std.meta : AliasSeq, staticMap;

        staticMap!(_sqlRepr, Args) ret = args;
        return tuple(ret);
    }

    static auto exec(alias handler = (_) {  }, Args...)(Statement stmt, auto ref Args args)
    {
        stmt.bindAll(args);
        scope (exit)
        {
            stmt.clearBindings();
            stmt.reset();
        }
        return handler(stmt.execute);
    }

    Statement _all, _find, _insert, _update, _remove;
    Database _db;
}

//==============================================================================
// Data Sources
//==============================================================================

struct Serie
{
    string name;
    Tuple!(long, float)[] data; // timestamps and values
}

interface DataSource
{
    Serie[] query(string query, Duration ago, int maxDataPoints = -1);
}

//------------------------------------------------------------------------------
// Graphite
//------------------------------------------------------------------------------

class Graphite : DataSource
{
    this(string url)
    {
        this.url = url;
    }

    override Serie[] query(string query, Duration ago, int maxDataPoints = -1)
    {
        import std.uri : encodeComponent;

        // add a 60s lag to avoid incorrect results for out-of-order collectd stats
        auto url = url ~ "/render?from=-" ~ (ago + 1.minutes).total!"seconds".to!string ~ "s&until=-60s&"
            ~ "format=raw&target=" ~ encodeComponent(query);
        auto response = requestHTTP(url);
        auto content = response.bodyReader.readAllUTF8;
        enforceHTTP(response.statusCode == 200, cast(HTTPStatus) response.statusCode,
            content);

        Serie[] series;
        foreach (line; content.lineSplitter)
        {
            import std.algorithm.iteration : filter, reduce;
            import std.algorithm.searching : findSplit;
            import std.format : formattedRead;
            import std.math : isNaN;
            import std.range : chunks;

            Serie s;
            long beg, end;
            uint step;
            auto parts = line.findSplit("|");
            enforceHTTP(parts[1] == "|", HTTPStatus.internalServerError,
                "Failed to parse graphite response.\n" ~ line);
            enforceHTTP(formattedRead(parts[0], "%s,%s,%s,%s", &s.name, &beg,
                &end, &step) == 4, HTTPStatus.internalServerError,
                "Failed to parse graphite response.\n" ~ line);

            immutable count = (end - beg) / step;
            immutable chunkSize = (maxDataPoints == -1 || maxDataPoints > count) ? 1 : count / maxDataPoints;
            s.data.length = count / chunkSize;
            size_t idx;

            foreach (chunk; parts[2].splitter(',').chunks(chunkSize))
            {
                auto values = chunk.filter!(v => v != "None").map!(v => v.to!double);
                if (!values.empty)
                    s.data[idx++] = tuple(beg * 1000 /*ms*/ , values.reduce!max);
                beg += chunkSize * step;
            }
            s.data.length = idx;
            series ~= s;
        }
        return series;
    }

private:
    string url;
}

DataSource dataSource(string type, string url)
{
    switch (type)
    {
    case "graphite":
        return new Graphite(url);
    default:
        throw new Exception("Unknown data source " ~ type);
    }
}

//==============================================================================
// API (Controllers)
//==============================================================================

struct Subscription
{
    string type, value;
}

@path("/api")
interface IAlertdAPI
{
    @path("checks")
    Check createCheck(string name, string dataSource, string query,
        float threshold, Subscription[] subscriptions = null);

    @path("checks/:id")
    Check getCheck(int _id);

    @path("checks/:id")
    Check updateCheck(int _id, string name, string dataSource, string query,
        float threshold, Subscription[] subscriptions = null, string state = null);

    @path("checks/:id")
    void deleteCheck(int _id);

    @queryParam("query", "q") @queryParam("dataSource", "data_source")
    Serie[] getGraphData(string dataSource, string query);
}

final class AlertdAPI : IAlertdAPI
{
    static struct Config
    {
        static struct DataSource
        {
            string type, url;
            @optional string name;
        }

        DataSource[] data_sources;
        static struct NotificationChannel
        {
            string name, command;
        }

        NotificationChannel[] notification_channels;
        string subject_template;
        string message_template;
    }

    this(Database db, Config cfg)
    {
        // TODO: verify config data (e.g. check emptiness)
        foreach (ds; cfg.data_sources)
            _dataSources[ds.name.empty ? ds.type : ds.name] = dataSource(ds.type, ds.url);
        foreach (nc; cfg.notification_channels)
            _channels[nc.name] = nc.command;
        _subjectTemplate = cfg.subject_template;
        _messageTemplate = cfg.message_template;

        _checks = Statements!Check(db);
        foreach (c; _checks.all)
            armCheck(c.id);
    }

    auto initData()
    {
        static struct InitData
        {
            string[] data_sources, notification_channels;
            Check[] checks;
        }

        return InitData(_dataSources.keys, _channels.keys, _checks.all);
    }

    Check createCheck(string name, string dataSource, string query,
        float threshold, Subscription[] subscriptions = null)
    {
        Check c;
        c.name = name;
        c.dataSource = dataSource;
        c.query = query;
        c.threshold = threshold;
        c.subscriptions = serializeToJson(subscriptions).toString;
        if (auto err = c.validate())
            throw new HTTPStatusException(HTTPStatus.badRequest, err);
        c.state = runCheck(dataSource, query, threshold)[0];
        _checks.insert(c);
        armCheck(c.id);
        logInfo("created %s", c);
        return c;
    }

    Check getCheck(int _id)
    {
        return _checks.find(_id);
    }

    Check updateCheck(int _id, string name, string dataSource, string query,
        float threshold, Subscription[] subscriptions = null, string state = null)
    {
        import std.exception : collectException;
        import std.conv : ConvException;

        auto c = _checks.find(_id);
        c.name = name;
        c.dataSource = dataSource;
        c.query = query;
        c.threshold = threshold;
        c.subscriptions = serializeToJson(subscriptions).toString;
        if (state)
        {
            try
                c.state = to!State(state);
            catch (ConvException ce)
                throw new HTTPStatusException(HTTPStatus.badRequest, "Invalid state '" ~ state ~ "'");
        }
        if (auto err = c.validate())
            throw new HTTPStatusException(HTTPStatus.badRequest, err);
        c.state = runCheck(dataSource, query, threshold)[0];
        _checks.update(c);
        logInfo("updated %s", c);
        return c;
    }

    void deleteCheck(int _id)
    {
        auto c = _checks.find(_id);
        dearmCheck(c.id);
        _checks.remove(c);
        logInfo("deleted %s", c);
    }

    Serie[] getGraphData(string dataSource, string query)
    {
        enum maxDataPoints = 7 * 24 * 6;
        auto ds = dataSource in _dataSources;
        enforceHTTP(ds, HTTPStatus.notFound, "Unknown data source '" ~ dataSource ~ "'");
        return ds.query(query, 7.days, maxDataPoints);
    }

private:

    auto runCheck(string dataSource, string query, float threshold)
    {
        auto ds = dataSource in _dataSources;
        enforceHTTP(ds, HTTPStatus.notFound, "Unknown data source '" ~ dataSource ~ "'");
        foreach (serie; ds.query(query, 10.minutes))
        {
            auto found = serie.data.find!(d => d[1] > threshold);
            if (!found.empty)
                return tuple(State.error, serie.name, found.front[1]);
        }
        return tuple(State.ok, "", 0.0f);
    }

    static string expandVars(string s, in string[string] env)
    {
        import std.regex : ctRegex, replaceAll;

        enum varRE = ctRegex!`\$([\w_]+)|\$\{([\w_]+)\}`;
        return s.replaceAll!(m => env[m[1].length ? m[1] : m[2]])(varRE);
    }

    unittest
    {
        assert(expandVars("Hello $FOO_BAR", ["FOO_BAR" : "test"]) == "Hello test");
        assert(expandVars("Hello ${FOO_BAR}", ["FOO_BAR" : "test"]) == "Hello test");
        assert(expandVars("Hello $FOO-BAR", ["FOO" : "test"]) == "Hello test-BAR");
        assert(expandVars("Hello $FOO:BAR", ["FOO" : "test"]) == "Hello test:BAR");
    }

    void runNotifications(Check c, string serie, float value)
    {
        auto subs = c.subscriptions.toRepresentation;
        if (subs.empty)
            return;

        auto env = [
            "NAME" : c.name, "DATA_SOURCE" : c.dataSource, "QUERY" : c.query,
            "THRESHOLD" : c.threshold.to!string, "SERIE" : serie, "VALUE" : value.to!string,
        ];
        env["SUBJECT"] = expandVars(_subjectTemplate, env);
        auto msg = env["MESSAGE"] = expandVars(_messageTemplate, env);

        foreach (key, ref val; env)
            val = escapeShellVariable(val);

        foreach (sub; c.subscriptions.toRepresentation)
        {
            if (auto channel = sub.type in _channels)
            {
                env["RECIPIENT"] = sub.value;
                runCommand(*channel, msg, env);
            }
            else
            {
                logWarn("Ignoring unknown notification channel %s for subscription %s.",
                    sub.type, sub.value);
            }
        }
    }

    static void runCommand(string command, string message, in string[string] env)
    {
        import std.process, std.process : Config;

        logInfo("Running %s with env %-(%s='%s'%| %).", command, env);
        enum redirect = Redirect.stdin | Redirect.stdout | Redirect.stderrToStdout;
        auto p = pipeShell(command, redirect, env, Config.newEnv);
        p.stdin.write(message);
        p.stdin.close();

        auto dur = 1.msecs, total = 0.msecs;
        auto res = tryWait(p.pid);
        while (!res.terminated)
        {
            if (total >= 5.seconds)
            {
                kill(p.pid);
                logError("Command '%s' timed out after 5 seconds.\n%-(  %s\n%)",
                    command, p.stdout.byLine);
                wait(p.pid);
                return;
            }
            sleep(dur);
            total += dur;
            if (dur < 128.msecs)
                dur += dur;
            res = tryWait(p.pid);
        }
        if (res.status)
        {
            logError("Command '%s' failed with status '%d'.\n%-(  %s\n%)",
                command, res.status, p.stdout.byLine);
        }
    }

    void armCheck(int checkID)
    {
        void doCheck()
        {
            auto c = _checks.find(checkID);
            auto res = runCheck(c.dataSource, c.query, c.threshold);
            logInfo("%s -> %s", c.name, res[0]);
            if (res[0] != c.state)
            {
                c.state = res[0];
                _checks.update(c);
                if (res[0] == State.error)
                    runNotifications(c, res[1 .. $]);
            }
        }

        assert(checkID !in _checkJobs);
        // TODO: make interval configurable
        import std.random;

        _checkJobs[checkID] = setTimer(uniform(0, 60).seconds, {
            _checkJobs[checkID].rearm(1.minutes, true);
            doCheck();
        });
    }

    void dearmCheck(int checkID)
    {
        assert(checkID in _checkJobs);
        _checkJobs[checkID].stop();
        _checkJobs.remove(checkID);
    }

    DataSource[string] _dataSources;
    string[string] _channels;
    Statements!Check _checks;
    Timer[int] _checkJobs;
    string _subjectTemplate, _messageTemplate;
}

string escapeShellVariable(string s)
{
    return s.replace("\r", "\\r").replace("\n", "\\n").replace("\t", "\\t");
}
