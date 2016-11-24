import { BrowserModule } from '@angular/platform-browser';
import { APP_INITIALIZER, NgModule } from '@angular/core';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { HttpModule } from '@angular/http';

import { AppComponent, CheckDetails, Ng2Highcharts2, SubscriptionComponent, CheckComponent, MatchChecks } from './app.component';
import { Backend } from './backend.service';

// preload init data
// https://github.com/angular/angular/issues/9047#issuecomment-255597990
export function loadInitData(backend: Backend) {
    return () => backend.loadInitData();
}

@NgModule({
  declarations: [
    CheckDetails,
    Ng2Highcharts2,
    SubscriptionComponent,
    AppComponent,
    CheckComponent,
    MatchChecks,
  ],
  imports: [
    BrowserModule,
    FormsModule,
    ReactiveFormsModule, // for [formControl] FormControlDirective
    HttpModule
  ],
  providers: [
      Backend,
      // https://gist.github.com/fernandohu/122e88c3bcd210bbe41c608c36306db9
      { provide: APP_INITIALIZER, useFactory: loadInitData, deps: [Backend], multi: true }
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }
