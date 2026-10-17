import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getSummary from '@salesforce/apex/ReconDashboardController.getSummary';

export default class ReconDashboard extends NavigationMixin(LightningElement) {
    summary;
    error;
    wiredResult;

    @wire(getSummary)
    wiredSummary(result) {
        this.wiredResult = result;
        if (result.data) {
            this.summary = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error?.body?.message || '대조 현황을 불러오지 못했습니다.';
        }
    }

    get oldestLabel() {
        return this.summary?.oldestOpenDays == null ? '없음' : `${this.summary.oldestOpenDays}일`;
    }

    get causeBars() {
        return this.toBars(this.summary?.byCause);
    }

    get handlerBars() {
        return this.toBars(this.summary?.byHandler);
    }

    get hasOpenItems() {
        return this.summary?.openItems > 0;
    }

    get rows() {
        return (this.summary?.needsReportRows || []).map((row) => ({
            ...row,
            dateLabel: this.formatDate(row.reconDate),
            differenceLabel: this.formatWon(row.difference),
            openLabel: `${row.openCount ?? 0}건`
        }));
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    toBars(list) {
        const items = list || [];
        const max = Math.max(1, ...items.map((item) => item.value));
        return items.map((item) => ({
            ...item,
            style: `width: ${Math.round((item.value / max) * 100)}%`
        }));
    }

    formatWon(value) {
        if (value == null) return '-';
        const sign = value > 0 ? '+' : value < 0 ? '-' : '';
        return `${sign}${Math.abs(value).toLocaleString('ko-KR')}원`;
    }

    formatDate(value) {
        if (!value) return '';
        const [, month, day] = value.split('-');
        return `${Number(month)}/${Number(day)}`;
    }

    handleRefresh() {
        refreshApex(this.wiredResult);
    }

    openRecord(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.target.dataset.id,
                objectApiName: 'Daily_Recon__c',
                actionName: 'view'
            }
        });
    }

    openNeedsReport() {
        this.openList('Daily_Recon__c', 'Needs_Report');
    }

    openOpenItems() {
        this.openList('Recon_Item__c', 'Open_Items');
    }

    openList(objectApiName, filterName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName, actionName: 'list' },
            state: { filterName }
        });
    }
}