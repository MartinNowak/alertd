import {bootstrap} from '@angular/platform-browser-dynamic'
import {enableProdMode} from '@angular/core'
import {AppComponent} from './app.component'
import {Injector, ReflectiveInjector} from '@angular/core';
import {HTTP_PROVIDERS} from '@angular/http';
import {Backend} from './backend.service'

if (process.env.ENV === 'production') {
  enableProdMode();
}
bootstrap(AppComponent, [HTTP_PROVIDERS, Backend]);
