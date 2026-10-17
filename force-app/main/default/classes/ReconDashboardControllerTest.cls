@IsTest
private class ReconDashboardControllerTest {
  @IsTest
  static void summarizesStatusesCausesAndHandlers() {
    Employee__c handler = new Employee__c(
      Name = '테스트 담당',
      Industry__c = '금융',
      Active__c = true
    );
    insert handler;
    Daily_Recon__c open = new Daily_Recon__c(
      Recon_Date__c = Date.today().addDays(-2),
      Recon_Account__c = '패런트',
      System_Balance__c = 1000,
      Bank_Balance__c = 1500
    );
    Daily_Recon__c balanced = new Daily_Recon__c(
      Recon_Date__c = Date.today(),
      Recon_Account__c = '체킹',
      System_Balance__c = 1000,
      Bank_Balance__c = 1000
    );
    insert new List<Daily_Recon__c>{ open, balanced };
    insert new List<Recon_Item__c>{
      new Recon_Item__c(
        Daily_Recon__c = open.Id,
        Side__c = '통장에만',
        Amount__c = 300,
        Cause__c = '시스템 미반영',
        Handler_Employee__c = handler.Id,
        Deposit_Purpose__c = ReconDashboardController.URGENT_PURPOSE
      ),
      new Recon_Item__c(
        Daily_Recon__c = open.Id,
        Side__c = '통장에만',
        Amount__c = 200,
        Cause__c = '시스템 미반영'
      ),
      new Recon_Item__c(
        Daily_Recon__c = open.Id,
        Side__c = '시스템에만',
        Amount__c = 10,
        Cause__c = '중복 기록'
      ),
      new Recon_Item__c(
        Daily_Recon__c = open.Id,
        Side__c = '시스템에만',
        Amount__c = 5,
        Cause__c = '중복 기록',
        Resolved__c = true,
        Resolution_Note__c = '중복 확인'
      )
    };

    // 상태는 Flow가 정하므로, 기대값은 실제 저장된 상태에서 계산한다
    Integer expectedNeedsReport = 0, expectedDone = 0, expectedOther = 0;
    for (Daily_Recon__c d : [SELECT Status__c FROM Daily_Recon__c]) {
      if (d.Status__c == ReconDashboardController.STATUS_NEEDS_REPORT) {
        expectedNeedsReport++;
      } else if (d.Status__c == ReconDashboardController.STATUS_DONE) {
        expectedDone++;
      } else {
        expectedOther++;
      }
    }

    Test.startTest();
    ReconDashboardController.Summary summary = ReconDashboardController.getSummary();
    Test.stopTest();

    Assert.areEqual(expectedNeedsReport, summary.needsReport);
    Assert.areEqual(expectedDone, summary.done);
    Assert.areEqual(expectedOther, summary.inProgress);
    Assert.areEqual(expectedNeedsReport, summary.needsReportRows.size());
    Assert.areEqual(3, summary.openItems, '해결된 항목은 빼고 센다');
    Assert.areEqual(
      1,
      summary.urgentItems,
      '지급 대행 자금인 미해결 항목만 긴급 (경과일 2일)'
    );
    for (ReconDashboardController.DailyRow row : summary.needsReportRows) {
      Assert.isTrue(
        row.urgent,
        '지급 대행 자금 미해결 항목이 있는 대조는 긴급'
      );
    }
    Assert.areEqual(2, summary.oldestOpenDays);

    Assert.areEqual(
      '시스템 미반영',
      summary.byCause[0].label,
      '건수가 많은 원인이 먼저 온다'
    );
    Assert.areEqual(2, summary.byCause[0].value);
    Assert.areEqual(2, summary.byCause.size());

    Map<String, Integer> byHandler = new Map<String, Integer>();
    for (ReconDashboardController.CountRow row : summary.byHandler) {
      byHandler.put(row.label, row.value);
    }
    Assert.areEqual(1, byHandler.get('테스트 담당'));
    Assert.areEqual(2, byHandler.get('담당 미지정'));
    Assert.areEqual('담당 미지정', summary.byHandler[0].label);
  }

  @IsTest
  static void returnsEmptySummaryWithoutData() {
    ReconDashboardController.Summary summary = ReconDashboardController.getSummary();

    Assert.areEqual(0, summary.needsReport + summary.done + summary.inProgress);
    Assert.areEqual(0, summary.openItems);
    Assert.areEqual(0, summary.urgentItems);
    Assert.isNull(summary.oldestOpenDays);
    Assert.isTrue(summary.byCause.isEmpty());
    Assert.isTrue(summary.needsReportRows.isEmpty());
  }

  @IsTest
  static void treatsLongOpenItemsAsUrgent() {
    Assert.isTrue(
      ReconDashboardController.isUrgent(
        new Recon_Item__c(
          Deposit_Purpose__c = ReconDashboardController.URGENT_PURPOSE
        )
      )
    );
    Assert.isFalse(
      ReconDashboardController.isUrgent(
        new Recon_Item__c(Deposit_Purpose__c = '수납 대금')
      )
    );
  }

  @IsTest
  static void judgesReconUrgency() {
    Assert.isFalse(
      ReconDashboardController.isUrgentRecon(
        new Daily_Recon__c(Recon_Date__c = Date.today())
      ),
      '남은 항목이 없으면 긴급 아님'
    );
  }
}
