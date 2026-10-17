@IsTest
private class GamePerformanceQuickEntryControllerTest {
  @TestSetup
  static void setup() {
    insert new Employee__c(
      Name = GamePerformanceQuickEntryController.DEFAULT_EMPLOYEE_NAME,
      Industry__c = '게임',
      Active__c = true
    );
    insert new List<Campaign>{
      new Campaign(Name = 'Test Campaign With Data', IsActive = true),
      new Campaign(Name = 'Test Campaign Empty', IsActive = true)
    };
  }

  static Campaign campaign(String name) {
    return [SELECT Id FROM Campaign WHERE Name = :name LIMIT 1];
  }

  @IsTest
  static void returnsLatestDatedPerformance() {
    Id campaignId = campaign('Test Campaign With Data').Id;
    insert new List<Game_Marketing_Performance__c>{
      new Game_Marketing_Performance__c(
        Campaign__c = campaignId,
        Report_Date__c = Date.today().addDays(-2),
        Target_Installs__c = 10
      ),
      new Game_Marketing_Performance__c(
        Campaign__c = campaignId,
        Report_Date__c = Date.today().addDays(-1),
        Target_Installs__c = 20
      ),
      new Game_Marketing_Performance__c(
        Campaign__c = campaignId,
        Target_Installs__c = 30
      )
    };

    Test.startTest();
    GamePerformanceQuickEntryController.PerformanceView view = GamePerformanceQuickEntryController.getPerformance(
      campaignId
    );
    Test.stopTest();

    Assert.isFalse(view.isNew);
    Assert.areEqual(
      20,
      view.targetInstalls,
      '실적 기준일이 가장 최근인 레코드여야 합니다'
    );
  }

  @IsTest
  static void fallsBackToUndatedPerformance() {
    Id campaignId = campaign('Test Campaign With Data').Id;
    insert new Game_Marketing_Performance__c(
      Campaign__c = campaignId,
      Clicks__c = 7
    );

    GamePerformanceQuickEntryController.PerformanceView view = GamePerformanceQuickEntryController.getPerformance(
      campaignId
    );

    Assert.isFalse(view.isNew);
    Assert.areEqual(7, view.clicks);
  }

  @IsTest
  static void reportsNewWhenNoPerformance() {
    GamePerformanceQuickEntryController.PerformanceView view = GamePerformanceQuickEntryController.getPerformance(
      campaign('Test Campaign Empty').Id
    );

    Assert.isTrue(view.isNew);
    Assert.isNull(view.recordId);
    Assert.areEqual(Date.today(), view.reportDate);
  }

  @IsTest
  static void updatesExistingPerformance() {
    Id campaignId = campaign('Test Campaign With Data').Id;
    Game_Marketing_Performance__c rec = new Game_Marketing_Performance__c(
      Campaign__c = campaignId,
      Report_Date__c = Date.today()
    );
    insert rec;

    Test.startTest();
    GamePerformanceQuickEntryController.PerformanceView view = GamePerformanceQuickEntryController.savePerformance(
      campaignId,
      rec.Id,
      100,
      80,
      400
    );
    Test.stopTest();

    Game_Marketing_Performance__c saved = [
      SELECT Target_Installs__c, Actual_Installs__c, Clicks__c
      FROM Game_Marketing_Performance__c
      WHERE Id = :rec.Id
    ];
    Assert.areEqual(100, saved.Target_Installs__c);
    Assert.areEqual(80, saved.Actual_Installs__c);
    Assert.areEqual(400, saved.Clicks__c);
    Assert.areEqual(rec.Id, view.recordId);
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Game_Marketing_Performance__c
        WHERE Campaign__c = :campaignId
      ]
    );
  }

  @IsTest
  static void createsPerformanceWithDefaultEmployee() {
    Id campaignId = campaign('Test Campaign Empty').Id;

    Test.startTest();
    GamePerformanceQuickEntryController.PerformanceView view = GamePerformanceQuickEntryController.savePerformance(
      campaignId,
      null,
      50,
      0,
      120
    );
    Test.stopTest();

    Game_Marketing_Performance__c created = [
      SELECT
        Assigned_Employee__r.Name,
        Report_Date__c,
        Target_Installs__c,
        Actual_Installs__c,
        Clicks__c
      FROM Game_Marketing_Performance__c
      WHERE Campaign__c = :campaignId
    ];
    Assert.areEqual(
      GamePerformanceQuickEntryController.DEFAULT_EMPLOYEE_NAME,
      created.Assigned_Employee__r.Name
    );
    Assert.areEqual(Date.today(), created.Report_Date__c);
    Assert.areEqual(
      0,
      created.Actual_Installs__c,
      '0은 유효한 값으로 저장되어야 합니다'
    );
    Assert.isFalse(view.isNew);
  }

  @IsTest
  static void rejectsMissingCampaign() {
    try {
      GamePerformanceQuickEntryController.getPerformance(null);
      Assert.fail('예외가 발생해야 합니다');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e);
    }
  }

  @IsTest
  static void rejectsNegativeValues() {
    try {
      GamePerformanceQuickEntryController.savePerformance(
        campaign('Test Campaign Empty').Id,
        null,
        -1,
        null,
        null
      );
      Assert.fail('예외가 발생해야 합니다');
    } catch (AuraHandledException e) {
      Assert.areEqual(0, [SELECT COUNT() FROM Game_Marketing_Performance__c]);
    }
  }

  @IsTest
  static void rejectsRecordFromAnotherCampaign() {
    Game_Marketing_Performance__c other = new Game_Marketing_Performance__c(
      Campaign__c = campaign('Test Campaign With Data').Id
    );
    insert other;
    try {
      GamePerformanceQuickEntryController.savePerformance(
        campaign('Test Campaign Empty').Id,
        other.Id,
        1,
        1,
        1
      );
      Assert.fail('예외가 발생해야 합니다');
    } catch (AuraHandledException e) {
      Assert.isNull(
        [
          SELECT Target_Installs__c
          FROM Game_Marketing_Performance__c
          WHERE Id = :other.Id
        ]
        .Target_Installs__c
      );
    }
  }
}
