
import {debounceTime} from 'rxjs/operators';
import {ChangeDetectionStrategy, ChangeDetectorRef, Component, Directive,
        ElementRef, EventEmitter, Input, Output, Pipe, PipeTransform, SimpleChanges} from '@angular/core';
import {Backend} from './backend.service'
import {Check as BackendCheck, Subscription, Serie} from './api'
import {Http} from '@angular/http';
import {FormControl, Validators} from '@angular/forms';
import {Chart} from 'highcharts';


//==============================================================================
// Highcharts
//==============================================================================

@Directive({
    selector: 'highcharts',
})
export class Ng2Highcharts2 {

    // http://api.highcharts.com/highcharts#colors
    colors = ['#7cb5ec', '#434348', '#90ed7d', '#f7a35c', '#8085e9',
              '#f15c80', '#e4d354', '#2b908f', '#f45b5b', '#91e8e1'];

    constructor(private _ele: ElementRef) {}

    @Input() set options(opt: Highcharts.Options) {
	if (this.chart) {
	    this.chart.destroy();
	}
        opt['chart']['renderTo'] = this._ele.nativeElement;
	this.chart = new Chart(opt);
        this.chart.showLoading();
    }

    @Input() set data(data: Highcharts.LineChartSeriesOptions[]) {
        if (!data) return;

        const redraw = true;
        while (this.chart.series.length)
            this.chart.series[0].remove(!redraw);
        for (var i = 0; i < data.length; ++i) {
            data[i].color = this.colors[i % this.colors.length];
            this.chart.addSeries(data[i], !redraw, false);
        }
        this.chart.redraw();
        this.chart.hideLoading();

        var extremes = this.chart.yAxis[0].getExtremes();
        this.minMaxChange.emit([extremes.min, extremes.max]);
    }

    @Input() set msg(msg: string) {
        if (msg.length)
            this.chart.showLoading(msg);
    }

    @Input() set threshold(value: number) {
        if (!value) return;
        if (!this.chart) return;
        this.chart.yAxis[0].removePlotLine('threshold');
        this.chart.yAxis[0].addPlotLine({
            value: value,
            color: '#D9534F',
            width: 2,
            id: 'threshold'
        });
    }

    @Output() minMaxChange = new EventEmitter<[number, number]>();
    private chart: Highcharts.ChartObject;
}

//==============================================================================
// Subscription
//==============================================================================

var notificationChannels: string[];

@Component({
    selector: 'subscription',
    templateUrl: './subscription.html',
})
export class SubscriptionComponent {
    @Input() subscription: Subscription = {type: notificationChannels[0], value: ""};

    get notificationChannels(): string[] {
      return notificationChannels;
    }
}

//==============================================================================
// CheckDetails
//==============================================================================

var dataSources: string[];

@Component({
    selector: 'check-details',
    styleUrls: ['./check_details.css'],
    templateUrl: './check_details.html'
})
export class CheckDetails {
    @Input() check: Check;
    @Output() saveCheck: EventEmitter<Check> = new EventEmitter<Check>();
    newSubscription: Subscription = {type: notificationChannels[0], value: ""};
    queryControl = new FormControl();

    chartData: Highcharts.LineChartSeriesOptions[];
    msg: string = '';
    min: number;
    max: number;
    chartOptions: Highcharts.Options = {
        title: {
            text: '',
            style: '{display: none;}'
        },
        chart: {
            animation: false,
            type: 'line',
            zoomType: 'x'
        },
        xAxis: {
            type: 'datetime'
        },
        yAxis: {
            title: {
                text: '',
            }
        },
        plotOptions: {
            series: {
                animation: false,
            }
        },
        tooltip: {
            positioner: () => { return { x: 20, y: 0 }; },
            shadow: false,
            borderWidth: 0,
            backgroundColor: 'rgba(255,255,255,0)',
            pointFormat: '<span style="color:{point.color}">\u25CF</span> {series.name}: <b>{point.y:.2f}</b><br/>'
        }
    };

    constructor(private _backend: Backend, private _changeDetector: ChangeDetectorRef) {}

    save(): void {
        if (this.newSubscription.value)
            this.addSubscription();
        this.saveCheck.emit(this.check);
    }

    updateDataSource(dataSource: string) {
        this.check.dataSource = dataSource;
        this.reloadData();
    }

    get dataSources() {
        return dataSources;
    }

    ngOnInit() {
        this.check.threshold = parseFloat(this.check.threshold.toFixed(1));
        this.queryControl.valueChanges.pipe(debounceTime(400))
            .subscribe(_ => this.reloadData());
    }

    ngOnChanges(changes: SimpleChanges) {
        this.reloadData();
    }

    private reloadData(): void {
        this._backend.graphData(this.check)
            .subscribe(
                series => this.updateGraph(series),
                error => { this.msg = <any>error; this.markDirty(); });
    }

    private updateGraph(series: Serie[]) {
        if (!series.length) {
            this.msg = 'No result';
            return;
        }
        this.msg = '';
        // prevent slider from saturating value
        this.min = this.max = this.check.threshold;
        this.chartData = series;
        this.markDirty();
    }

    private loadError(error: string) {
        console.log(error);
    }

    minMaxChange(minmax: [number, number]) {
        this.min = minmax[0];
        this.max = minmax[1];
    }

    /*static*/ toFloat(val: string, digits: number): number {
        return parseFloat(parseFloat(val).toFixed(digits));
    }

    addSubscription(e?: Event) {
        if (e) e.preventDefault();
        this.check.subscriptions.push(this.newSubscription);
        this.newSubscription = {type: this.newSubscription.type, value: ""};
    }

    private deleteSubscription(s: Subscription) {
        var idx = this.check.subscriptions.indexOf(s);
        this.check.subscriptions.splice(idx, 1);
    }

    private markDirty(): void {
        this._changeDetector.markForCheck();
    }
}

//==============================================================================
// Check
//==============================================================================

@Component({
    selector: 'check',
    styleUrls: ['./check.css'],
    template: `
        <div class="bar row" (click)="toggleSelect.emit(check)">
          <div class="two columns text-align-center" [ngClass]="{error: check.state == 'error', ok: check.state == 'ok'}">{{check.state}}</div>
          <div class="eight columns text-overflow-ellipsis">{{check.name}}</div>
          <!-- careful order reversed due to float right (u-pull-right) -->
          <div class="one column text-align-center u-pull-right error" (click)="remove($event)" title="remove">✖</div>
          <div class="one column text-align-center u-pull-right error" (click)="copy($event)" title="copy">⎘</div>
        </div>
        <check-details *ngIf="selected" [check]="check" (saveCheck)="saveCheck.emit($event)"></check-details>
        `,
})
export class CheckComponent {
    @Input() check: Check;
    @Input() selected: boolean;
    @Output() saveCheck = new EventEmitter<Check>();
    @Output() copyCheck = new EventEmitter<Check>();
    @Output() removeCheck = new EventEmitter<Check>();
    @Output() toggleSelect = new EventEmitter<Check>();

    copy(e: MouseEvent) {
        e.stopPropagation();
        this.copyCheck.emit(this.check);
    }

    remove(e: MouseEvent) {
        e.stopPropagation();
        this.removeCheck.emit(this.check);
    }
}

//==============================================================================
// Pipes
//==============================================================================

// See http://bit.ly/1n9ZVd5 for why this is marked as impure
@Pipe({name: 'matchChecks', pure: false})
export class MatchChecks implements PipeTransform {
    transform(checks: Check[], pattern: string): Check[] {
        var words = pattern.trim().toLowerCase().split(/\s+/);
        return checks.filter(c => {
            const name = c.name.toLowerCase();
            return words.some(w => name.indexOf(w) != -1);
        });
    }
}

//==============================================================================
// App
//==============================================================================

export interface Check extends BackendCheck {
    selected?: boolean;
}

@Component({
    selector: 'app-root',
    styles: [`check { display: block; margin-top: .75rem; }`],
    templateUrl: './app.component.html',
    changeDetection: ChangeDetectionStrategy.OnPush
})
export class AppComponent {
    checks: Check[] = [];
    filterExpr: string = '';

    constructor(private _backend: Backend, private _changeDetector: ChangeDetectorRef) {
        var initData = _backend.initData
        dataSources = initData.data_sources;
        notificationChannels = initData.notification_channels;
        this.checks = initData.checks;
    }

    addCheck(): void {
        var c: Check = {name: 'New Check', dataSource: dataSources[0], query: null, state: 'unsaved', threshold: 0, subscriptions: [], selected: true};
        this.checks.unshift(c);
    }

    copyCheck(c: Check): void {
        this.checks.unshift({...c, id: null, name: c.name + ' Copy', state: 'unsaved', selected: true});
    }

    saveCheck(c: Check): void {
        this._backend.saveCheck(c).subscribe(newc => {
            this.replace(c, newc);
        });
    }

    removeCheck(c: Check): void {
        if (!confirm('Are you sure you want to remove this check?'))
            return;
        this._backend.removeCheck(c).subscribe(res => {
            if (res[0]) {
                var idx = this.checks.indexOf(c);
                this.checks.splice(idx, 1);
                this.markDirty();
            }
        });
    }

    toggleSelect(c: Check): void {
        if (c.selected)
            delete c.selected;
        else
            c.selected = true;
    }

    private replace(oldc: Check, newc: Check) {
        var idx = this.checks.indexOf(oldc);
        newc.selected = oldc.selected;
        this.checks[idx] = newc;
        this.markDirty();
    }

    private markDirty(): void {
        this._changeDetector.markForCheck();
    }
}
