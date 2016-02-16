import vibe.d;
import std.getopt, std.json;
import d2sqlite3;
import alertd;

Json filterComments(Json json)
{
    auto ret = Json(cast(Json[string]) null);
    foreach (string k, v; json)
        if (!k.startsWith("#"))
            ret[k] = v.type == Json.Type.object ? filterComments(v) : v;
    return ret;
}

void main(string[] args)
{
    string configPath = "alertd.json";
    auto settings = new HTTPServerSettings;
    settings.bindAddresses = ["localhost"];
    string dbPath = "alertd.db";
    string publicPath = "public";
    settings.port = 8080;
    bool verbose;

    // dfmt off
    auto helpInformation = getopt(
        args,
        "f|config", "path to config file (%s)".format(configPath), &configPath,
        "db", "path to sqlite3 database (%s)".format(dbPath), &dbPath,
        "host", "IP address to bind (%s)".format(settings.bindAddresses[0]), &settings.bindAddresses[0],
        "public-path", "path to static assets (%s)".format(publicPath), &publicPath,
        "p|port", "port to listen on (%s)".format(settings.port), &settings.port,
        "v|verbose", "enable verbose logging", &verbose,
    );
    // dfmt on

    if (helpInformation.helpWanted)
        return defaultGetoptPrinter("alertd\n", helpInformation.options);

    import std.file : readText;

    auto jcfg = filterComments(configPath.readText.parseJsonString(configPath));
    auto cfg = jcfg.deserializeJson!(AlertdAPI.Config);
    LogConfig logcfg;
    if (auto p = "logger" in jcfg)
        logcfg = deserializeJson!LogConfig(*p);

    setLogLevel(LogLevel.none); // disable default logger
    registerLogger(logcfg.createLogger(verbose));

    auto db = Database(dbPath);
    static AlertdAPI api;
    api = new AlertdAPI(db, cfg);

    auto router = new URLRouter;
    router.registerRestInterface(api);
    router.get("/", (req, res) {
        auto initData = api.initData.serializeToJsonString;
        res.render!("index.dt", initData);
    });
    router.get("*", serveStaticFiles(publicPath));
    listenHTTP(settings, router);

    lowerPrivileges();
    runEventLoop();
}

struct LogConfig
{
    enum Destination
    {
        stdout_stderr,
        syslog,
        file
    }

    @byName Destination destination = Destination.stdout_stderr;
    @optional @byName LogLevel level = LogLevel.info;
    @optional string path = "alertd.log";
    @optional @byName SyslogLogger.Facility facility = SyslogLogger.Facility.user;

    shared(Logger) createLogger(bool verbose)
    {
        Logger logger;
        final switch (destination)
        {
        case Destination.stdout_stderr:
            import std.stdio : stdout, stderr;

            logger = new FileLogger(stdout, stderr);
            break;

        case Destination.syslog:
            logger = new SysLogger("alertd", facility);
            break;

        case Destination.file:
            logger = new FileLogger(path);
            break;
        }
        logger.minLevel = verbose ? LogLevel.diagnostic : level;
        return cast(shared) logger;
    }
}

version (Posix) class SysLogger : Logger
{
    import core.sys.posix.syslog;

    this(string identifier, SyslogLogger.Facility facility)
    {
        _identifier = toStringz(identifier);
        openlog(_identifier, LOG_PID | LOG_CONS, facility);
    }

    override void beginLine(ref LogLine info) @trusted
    {
        static assert(LogLevel.fatal - LogLevel.debugV == 7);
        prio = 7 - (max(info.level, LogLevel.debugV) - LogLevel.debugV);
    }

    override void put(scope const(char)[] text) @trusted
    {
        buf.put(text);
    }

    override void endLine() @trusted
    {
        syslog(prio, "%.*s", cast(int) buf.data.length, buf.data.ptr);
        buf.clear;
    }

    ~this()
    {
        closelog();
    }

private:
    int prio;
    const char* _identifier;
    Appender!(char[]) buf;
}
