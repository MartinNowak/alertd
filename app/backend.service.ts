import {Injectable} from '@angular/core';
import {Headers, Http, RequestMethod} from '@angular/http';
import 'rxjs/add/operator/map';
import 'rxjs/add/operator/catch';
import 'rxjs/add/observable/throw';
import {Observable} from 'rxjs/Observable';
import {ScalarObservable} from 'rxjs/observable/ScalarObservable';

export interface Check {
    id?: number,
    name: string,
    dataSource: string,
    query: string,
    threshold: number,
    state: string,
    subscriptions: Subscription[]
}

export interface Serie {
    name: string,
    data: [number, number][]
}

export interface Subscription {
    type: string,
    value: string
}

@Injectable()
export class Backend {

    constructor(private _http: Http) {
    }

    saveCheck(c: Check) {
        var url = c.id ? 'api/checks/'+c.id : 'api/checks';
        var method = c.id ? RequestMethod.Patch : RequestMethod.Post;
        var headers = new Headers({'Content-Type': 'application/json'});
        var body = JSON.stringify(c);
        return this._http.request(url, {method: method, headers: headers, body: body})
            .map(res => <Check>res.json());
    }

    removeCheck(c: Check) {
        var url = 'api/checks/'+c.id;
        var method = RequestMethod.Delete;
        return c.id ? this._http.request(url, {method: method})
            .map(res => [res.ok, res.statusText]) : new ScalarObservable([true, 'OK']);
    }

    unarchiveCheck(c: Check) {
        c.state = 'unknown';
        return c.id ? this.saveCheck(c) : new ScalarObservable(c);
    }

    graphData(c: Check) {
        var url = 'api/graph_data?q=' + encodeURIComponent(c.query) +
            '&data_source=' + encodeURIComponent(c.dataSource);
        return this._http.get(url).map(res => <Serie[]>res.json())
            .catch(res => Observable.throw(res.json().error || 'Database error'));
    }
}
