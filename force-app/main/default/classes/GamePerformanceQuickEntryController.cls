/**
 * 게임 마케팅 성과 빠른 입력(LWC gamePerformanceQuickEntry)의 서버 로직.
 * Flow "Game Performance Quick Entry"와 같은 규칙을 따른다.
 *  - 캠페인의 성과 중 실적 기준일이 가장 최근인 1건, 없으면 가장 최근 수정된 1건을 편집 대상으로 한다.
 *  - 성과가 없으면 저장 시 신규 생성한다(담당 직원: 최산, 실적 기준일: 오늘).
 */
public with sharing class GamePerformanceQuickEntryController {
  @TestVisible
  static final String DEFAULT_EMPLOYEE_NAME = '최산';

  public class PerformanceView {
    @AuraEnabled
    public Id campaignId;
    @AuraEnabled
    public String campaignName;
    @AuraEnabled
    public Id recordId;
    @AuraEnabled
    public String recordName;
    @AuraEnabled
    public Date reportDate;
    @AuraEnabled
    public String employeeName;
    @AuraEnabled
    public Decimal targetInstalls;
    @AuraEnabled
    public Decimal actualInstalls;
    @AuraEnabled
    public Decimal clicks;
    @AuraEnabled
    public Boolean isNew;
  }

  @AuraEnabled
  public static PerformanceView getPerformance(Id campaignId) {
    Campaign campaign = findCampaign(campaignId);
    Game_Marketing_Performance__c record = findLatestPerformance(campaignId);

    PerformanceView view = new PerformanceView();
    view.campaignId = campaign.Id;
    view.campaignName = campaign.Name;
    view.isNew = (record == null);
    if (record == null) {
      view.reportDate = Date.today();
      view.employeeName = DEFAULT_EMPLOYEE_NAME;
    } else {
      view.recordId = record.Id;
      view.recordName = record.Name;
      view.reportDate = record.Report_Date__c;
      view.employeeName = record.Assigned_Employee__r?.Name;
      view.targetInstalls = record.Target_Installs__c;
      view.actualInstalls = record.Actual_Installs__c;
      view.clicks = record.Clicks__c;
    }
    return view;
  }

  @AuraEnabled
  public static PerformanceView savePerformance(
    Id campaignId,
    Id recordId,
    Decimal targetInstalls,
    Decimal actualInstalls,
    Decimal clicks
  ) {
    validateNonNegative('목표 설치 수', targetInstalls);
    validateNonNegative('실제 설치 수', actualInstalls);
    validateNonNegative('클릭 수', clicks);
    findCampaign(campaignId);

    try {
      if (recordId != null) {
        List<Game_Marketing_Performance__c> existing = [
          SELECT Id
          FROM Game_Marketing_Performance__c
          WHERE Id = :recordId AND Campaign__c = :campaignId
          WITH USER_MODE
          LIMIT 1
        ];
        if (existing.isEmpty()) {
          throw new AuraHandledException(
            '선택한 캠페인의 성과 레코드를 찾을 수 없습니다. 다시 조회해 주세요.'
          );
        }
        Database.update(
          new Game_Marketing_Performance__c(
            Id = recordId,
            Target_Installs__c = targetInstalls,
            Actual_Installs__c = actualInstalls,
            Clicks__c = clicks
          ),
          AccessLevel.USER_MODE
        );
      } else {
        Database.insert(
          new Game_Marketing_Performance__c(
            Campaign__c = campaignId,
            Assigned_Employee__c = findDefaultEmployeeId(),
            Report_Date__c = Date.today(),
            Target_Installs__c = targetInstalls,
            Actual_Installs__c = actualInstalls,
            Clicks__c = clicks
          ),
          AccessLevel.USER_MODE
        );
      }
    } catch (DmlException e) {
      throw new AuraHandledException(
        '저장하지 못했습니다: ' + e.getDmlMessage(0)
      );
    }
    return getPerformance(campaignId);
  }

  private static Campaign findCampaign(Id campaignId) {
    if (campaignId == null) {
      throw new AuraHandledException('캠페인을 선택해 주세요.');
    }
    List<Campaign> campaigns = [
      SELECT Id, Name
      FROM Campaign
      WHERE Id = :campaignId
      WITH USER_MODE
      LIMIT 1
    ];
    if (campaigns.isEmpty()) {
      throw new AuraHandledException('캠페인을 찾을 수 없습니다.');
    }
    return campaigns[0];
  }

  private static Game_Marketing_Performance__c findLatestPerformance(
    Id campaignId
  ) {
    List<Game_Marketing_Performance__c> dated = [
      SELECT
        Id,
        Name,
        Report_Date__c,
        Assigned_Employee__r.Name,
        Target_Installs__c,
        Actual_Installs__c,
        Clicks__c
      FROM Game_Marketing_Performance__c
      WHERE Campaign__c = :campaignId AND Report_Date__c != NULL
      WITH USER_MODE
      ORDER BY Report_Date__c DESC, LastModifiedDate DESC
      LIMIT 1
    ];
    if (!dated.isEmpty()) {
      return dated[0];
    }
    List<Game_Marketing_Performance__c> latest = [
      SELECT
        Id,
        Name,
        Report_Date__c,
        Assigned_Employee__r.Name,
        Target_Installs__c,
        Actual_Installs__c,
        Clicks__c
      FROM Game_Marketing_Performance__c
      WHERE Campaign__c = :campaignId
      WITH USER_MODE
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];
    return latest.isEmpty() ? null : latest[0];
  }

  private static Id findDefaultEmployeeId() {
    List<Employee__c> employees = [
      SELECT Id
      FROM Employee__c
      WHERE Name = :DEFAULT_EMPLOYEE_NAME
      WITH USER_MODE
      ORDER BY CreatedDate
      LIMIT 1
    ];
    return employees.isEmpty() ? null : employees[0].Id;
  }

  private static void validateNonNegative(String label, Decimal value) {
    if (value != null && value < 0) {
      throw new AuraHandledException(label + '는 0 이상이어야 합니다.');
    }
  }
}
