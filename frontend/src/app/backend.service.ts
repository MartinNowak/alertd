
import {throwError as observableThrowError, Observable} from 'rxjs';

import {catchError, map} from 'rxjs/operators';
import {Injectable} from '@angular/core';
import {Headers, Http, RequestMethod} from '@angular/http';
import {ScalarObservable} from 'rxjs/observable/ScalarObservable';
import {InitData, Check, Subscription, Serie} from './api'

@Injectable()
export class Backend {
    initData: InitData;

    constructor(private _http: Http) {
    }

    loadInitData() {
        var url = 'api/init_data';
        return this._http.get(url).pipe(map(res => <InitData>res.json()))
            .toPromise()
            .then(initData => {
                this.initData = initData;
            });
    }

    saveCheck(c: Check) {
        var url = c.id ? 'api/checks/'+c.id : 'api/checks';
        var method = c.id ? RequestMethod.Patch : RequestMethod.Post;
        var headers = new Headers({'Content-Type': 'application/json'});
        var body = JSON.stringify(c);
        return this._http.request(url, {method: method, headers: headers, body: body}).pipe(
            map(res => <Check>res.json()));
    }

    removeCheck(c: Check) {
        var url = 'api/checks/'+c.id;
        var method = RequestMethod.Delete;
        return c.id ? this._http.request(url, {method: method}).pipe(
            map(res => [res.ok, res.statusText])) : ScalarObservable.create([true, 'OK']);
    }

    unarchiveCheck(c: Check) {
        c.state = 'unknown';
        return c.id ? this.saveCheck(c) : ScalarObservable.create(c);
    }

    graphData(c: Check) {
        var url = 'api/graph_data?q=' + encodeURIComponent(c.query) +
            '&data_source=' + encodeURIComponent(c.dataSource);
        return this._http.get(url).pipe(map(res => <Serie[]>res.json()),
            catchError(res => observableThrowError(res.json().error || 'Database error')),);
    }
}
