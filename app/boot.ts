import {bootstrap} from 'angular2/platform/browser'
import {enableProdMode} from 'angular2/core'
import {AppComponent} from './app.component'
import {Backend} from './backend.service'
import {HTTP_PROVIDERS} from 'angular2/http';

enableProdMode();
bootstrap(AppComponent, [Backend, HTTP_PROVIDERS]);
