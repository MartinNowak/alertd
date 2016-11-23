import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { HttpModule } from '@angular/http';

import { AppComponent, CheckDetails, Ng2Highcharts2, SubscriptionComponent, CheckComponent, MatchChecks } from './app.component';
import { Backend } from './backend.service';

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
  providers: [Backend],
  bootstrap: [AppComponent]
})
export class AppModule { }
