import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPerformance from '@salesforce/apex/GamePerformanceQuickEntryController.getPerformance';
import savePerformance from '@salesforce/apex/GamePerformanceQuickEntryController.savePerformance';

const NUMBER_FIELDS = ['targetInstalls', 'actualInstalls', 'clicks'];

export default class GamePerformanceQuickEntry extends LightningElement {
    campaignId;
    view;
    draft = {};
    isLoading = false;
    isSaved = false;
    errorMessage;

    get currentStep() {
        if (this.isSaved) return 'done';
        return this.view ? 'edit' : 'select';
    }

    get isSelectStep() {
        return this.currentStep === 'select';
    }

    get isEditStep() {
        return this.currentStep === 'edit';
    }

    get isDoneStep() {
        return this.currentStep === 'done';
    }

    get isSearchDisabled() {
        return !this.campaignId || this.isLoading;
    }

    get recordBadgeLabel() {
        if (!this.view) return '';
        return this.view.isNew ? '신규 생성 예정' : this.view.recordName;
    }

    get recordBadgeClass() {
        return this.view?.isNew ? 'badge badge_new' : 'badge badge_existing';
    }

    get employeeLabel() {
        if (!this.view?.employeeName) return '미지정';
        return this.view.isNew ? `${this.view.employeeName} (자동 지정)` : this.view.employeeName;
    }

    get achievementRate() {
        const { targetInstalls, actualInstalls } = this.draft;
        if (targetInstalls == null || targetInstalls <= 0 || actualInstalls == null) return null;
        return Math.round((actualInstalls / targetInstalls) * 100);
    }

    get achievementLabel() {
        return this.achievementRate == null ? '—' : `${this.achievementRate}%`;
    }

    get achievementBarValue() {
        return this.achievementRate == null ? 0 : Math.min(this.achievementRate, 100);
    }

    get achievementTileClass() {
        const rate = this.achievementRate;
        if (rate == null) return 'kpi';
        if (rate >= 100) return 'kpi kpi_good';
        if (rate >= 70) return 'kpi kpi_warn';
        return 'kpi kpi_bad';
    }

    get achievementHint() {
        const rate = this.achievementRate;
        if (rate == null) return '목표·실제 설치 수를 입력하면 계산됩니다';
        if (rate >= 100) return '목표를 달성했습니다';
        return `목표까지 ${Math.max(this.draft.targetInstalls - this.draft.actualInstalls, 0).toLocaleString()}건 남았습니다`;
    }

    get conversionLabel() {
        const { actualInstalls, clicks } = this.draft;
        if (clicks == null || clicks <= 0 || actualInstalls == null) return '—';
        return `${((actualInstalls / clicks) * 100).toFixed(1)}%`;
    }

    handleCampaignChange(event) {
        this.campaignId = event.detail.recordId;
        this.errorMessage = undefined;
    }

    async handleSearch() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            this.applyView(await getPerformance({ campaignId: this.campaignId }));
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleInput(event) {
        const field = event.target.dataset.field;
        const raw = event.target.value;
        this.draft = { ...this.draft, [field]: raw === '' || raw == null ? null : Number(raw) };
    }

    async handleSave() {
        const inputs = [...this.template.querySelectorAll('lightning-input')];
        const valid = inputs.reduce((ok, input) => input.reportValidity() && ok, true);
        if (!valid) return;

        this.isLoading = true;
        this.errorMessage = undefined;
        const wasNew = this.view.isNew;
        try {
            const result = await savePerformance({
                campaignId: this.view.campaignId,
                recordId: this.view.recordId,
                ...this.draft
            });
            this.applyView(result);
            this.isSaved = true;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: wasNew ? '성과 레코드를 생성했습니다' : '성과 레코드를 저장했습니다',
                    message: `${result.campaignName} · ${result.recordName}`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleEditAgain() {
        this.isSaved = false;
    }

    handleReset() {
        this.campaignId = undefined;
        this.view = undefined;
        this.draft = {};
        this.isSaved = false;
        this.errorMessage = undefined;
    }

    applyView(view) {
        this.view = view;
        this.draft = NUMBER_FIELDS.reduce((acc, field) => ({ ...acc, [field]: view[field] ?? null }), {});
    }

    reduceError(error) {
        return error?.body?.message || error?.message || '알 수 없는 오류가 발생했습니다.';
    }
}
