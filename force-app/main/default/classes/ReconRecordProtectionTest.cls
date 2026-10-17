/**
 * 입출금 대조 기록 보호 테스트.
 * 검증 규칙(처리 내용 필수, 완료 대조 잠금, 완료 대조 항목 추가 금지, 해결 항목 잠금)과 변경 이력 추적을 확인한다.
 */
@IsTest
private class ReconRecordProtectionTest {
    static Daily_Recon__c makeRecon(Decimal systemBalance, Decimal bankBalance) {
        Daily_Recon__c recon = new Daily_Recon__c(
            Recon_Date__c = Date.today(),
            Recon_Account__c = '패런트',
            System_Balance__c = systemBalance,
            Bank_Balance__c = bankBalance
        );
        insert recon;
        return [SELECT Id, Status__c FROM Daily_Recon__c WHERE Id = :recon.Id];
    }

    static Recon_Item__c makeItem(Id reconId) {
        Recon_Item__c item = new Recon_Item__c(Daily_Recon__c = reconId, Side__c = '통장에만', Amount__c = 300, Cause__c = '시스템 미반영');
        insert item;
        return item;
    }

    static Boolean isBlocked(SObject record, Boolean isInsert) {
        try {
            if (isInsert) {
                insert record;
            } else {
                update record;
            }
            return false;
        } catch (DmlException e) {
            return e.getDmlType(0) == StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION;
        }
    }

    @IsTest
    static void resolvingNeedsNote() {
        Recon_Item__c item = makeItem(makeRecon(1000, 1300).Id);

        Assert.isTrue(isBlocked(new Recon_Item__c(Id = item.Id, Resolved__c = true), false), '처리 내용 없이 해결 체크 불가');
        Assert.isFalse(isBlocked(new Recon_Item__c(Id = item.Id, Resolved__c = true, Resolution_Note__c = '재무팀 시스템 반영 완료'), false), '처리 내용이 있으면 해결 가능');
    }

    @IsTest
    static void completedReconIsLocked() {
        Daily_Recon__c recon = makeRecon(1000, 1000);
        Assert.areEqual('완료', recon.Status__c, '차이 0원, 남은 항목 0건이면 완료');

        Assert.isTrue(isBlocked(new Daily_Recon__c(Id = recon.Id, System_Balance__c = 900), false), '완료된 대조의 잔액은 못 고친다');
        Assert.isTrue(isBlocked(new Daily_Recon__c(Id = recon.Id, Recon_Date__c = Date.today().addDays(-1)), false), '완료된 대조의 대조일은 못 고친다');
        Assert.isTrue(
            isBlocked(new Recon_Item__c(Daily_Recon__c = recon.Id, Side__c = '통장에만', Amount__c = 1), true),
            '완료된 대조에는 항목을 추가할 수 없다'
        );
    }

    @IsTest
    static void openReconCanStillBeCorrected() {
        Recon_Item__c item = makeItem(makeRecon(1000, 1300).Id);

        update new Recon_Item__c(Id = item.Id, Resolved__c = true, Resolution_Note__c = '반영 완료');
        Assert.isFalse(isBlocked(new Daily_Recon__c(Id = item.Daily_Recon__c, System_Balance__c = 1300), false), '완료 전에는 잔액 정정 가능');
        Assert.areEqual('완료', [SELECT Status__c FROM Daily_Recon__c WHERE Id = :item.Daily_Recon__c].Status__c);
    }

    @IsTest
    static void resolvedItemIsLocked() {
        Recon_Item__c item = makeItem(makeRecon(1000, 1500).Id);
        makeItem(item.Daily_Recon__c); // 대조가 완료되지 않도록 항목 하나를 더 남겨 둔다
        update new Recon_Item__c(Id = item.Id, Resolved__c = true, Resolution_Note__c = '반영 완료');

        Assert.isTrue(isBlocked(new Recon_Item__c(Id = item.Id, Amount__c = 0), false), '해결된 항목의 금액은 못 고친다');
        Assert.isFalse(isBlocked(new Recon_Item__c(Id = item.Id, Resolved__c = false), false), '해결 체크를 푸는 것은 가능 (이력에 남음)');
        Assert.isFalse(isBlocked(new Recon_Item__c(Id = item.Id, Amount__c = 250), false), '해결을 푼 뒤에는 금액 정정 가능');
    }

    @IsTest
    static void historyIsTracked() {
        Map<String, Schema.SObjectType> types = Schema.getGlobalDescribe();
        Assert.isTrue(types.containsKey('daily_recon__history'), '일일 대조 변경 이력 사용');
        Assert.isTrue(types.containsKey('recon_item__history'), '미대조 항목 변경 이력 사용');
    }
}
