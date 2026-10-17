/**
 * 입출금 대조 앱 홈의 "입출금 대조 현황"(LWC reconDashboard) 데이터.
 * 일일 대조 상태별 건수, 미해결 항목의 원인별·처리 담당별 건수, 확인이 필요한 대조 목록을 돌려준다.
 */
public with sharing class ReconDashboardController {
    @TestVisible
    static final String STATUS_NEEDS_REPORT = '보고 필요';
    @TestVisible
    static final String STATUS_DONE = '완료';
    @TestVisible
    static final String URGENT_PURPOSE = '지급 대행 자금';
    @TestVisible
    static final Integer URGENT_DAYS = 3;

    public class CountRow {
        @AuraEnabled public String label;
        @AuraEnabled public Integer value;

        CountRow(String label, Integer value) {
            this.label = label;
            this.value = value;
        }
    }

    public class DailyRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Date reconDate;
        @AuraEnabled public String account;
        @AuraEnabled public Decimal difference;
        @AuraEnabled public Decimal openCount;
        @AuraEnabled public Boolean urgent;
    }

    public class Summary {
        @AuraEnabled public Integer needsReport = 0;
        @AuraEnabled public Integer inProgress = 0;
        @AuraEnabled public Integer done = 0;
        @AuraEnabled public Integer openItems = 0;
        @AuraEnabled public Integer urgentItems = 0;
        @AuraEnabled public Integer oldestOpenDays;
        @AuraEnabled public List<CountRow> byCause = new List<CountRow>();
        @AuraEnabled public List<CountRow> byHandler = new List<CountRow>();
        @AuraEnabled public List<DailyRow> needsReportRows = new List<DailyRow>();
    }

    @AuraEnabled(cacheable=true)
    public static Summary getSummary() {
        Summary summary = new Summary();

        for (AggregateResult ar : [
            SELECT Status__c status, COUNT(Id) cnt
            FROM Daily_Recon__c
            WITH USER_MODE
            GROUP BY Status__c
        ]) {
            String status = (String) ar.get('status');
            Integer cnt = (Integer) ar.get('cnt');
            if (status == STATUS_NEEDS_REPORT) {
                summary.needsReport += cnt;
            } else if (status == STATUS_DONE) {
                summary.done += cnt;
            } else {
                summary.inProgress += cnt;
            }
        }

        Map<String, Integer> causeCounts = new Map<String, Integer>();
        Map<String, Integer> handlerCounts = new Map<String, Integer>();
        for (Recon_Item__c item : [
            SELECT Cause__c, Handler_Employee__r.Name, Days_Open__c, Deposit_Purpose__c
            FROM Recon_Item__c
            WHERE Resolved__c = false
            WITH USER_MODE
        ]) {
            summary.openItems++;
            if (isUrgent(item)) {
                summary.urgentItems++;
            }
            increment(causeCounts, item.Cause__c ?? '원인 미입력');
            increment(handlerCounts, item.Handler_Employee__r?.Name ?? '담당 미지정');
            if (item.Days_Open__c != null && (summary.oldestOpenDays == null || item.Days_Open__c > summary.oldestOpenDays)) {
                summary.oldestOpenDays = item.Days_Open__c.intValue();
            }
        }
        summary.byCause = toSortedRows(causeCounts);
        summary.byHandler = toSortedRows(handlerCounts);

        for (Daily_Recon__c recon : [
            SELECT Id, Name, Recon_Date__c, toLabel(Recon_Account__c), Difference__c, Open_Item_Count__c, Urgent_Purpose_Open_Count__c
            FROM Daily_Recon__c
            WHERE Status__c = :STATUS_NEEDS_REPORT
            WITH USER_MODE
            ORDER BY Recon_Date__c DESC, Name DESC
            LIMIT 10
        ]) {
            DailyRow row = new DailyRow();
            row.id = recon.Id;
            row.name = recon.Name;
            row.reconDate = recon.Recon_Date__c;
            row.account = recon.Recon_Account__c;
            row.difference = recon.Difference__c;
            row.openCount = recon.Open_Item_Count__c;
            row.urgent = isUrgentRecon(recon);
            summary.needsReportRows.add(row);
        }
        return summary;
    }

    /** 긴급 기준: 입금 목적이 지급 대행 자금이거나 경과일 3일 이상 (미해결 항목만 조회됨, 필드 긴급도와 같은 규칙) */
    @TestVisible
    static Boolean isUrgent(Recon_Item__c item) {
        return item.Deposit_Purpose__c == URGENT_PURPOSE || (item.Days_Open__c != null && item.Days_Open__c >= URGENT_DAYS);
    }

    /** 일일 대조 긴급 기준 (필드 Daily_Recon__c.Urgency__c와 같은 규칙) */
    @TestVisible
    static Boolean isUrgentRecon(Daily_Recon__c recon) {
        Boolean hasOpen = (recon.Open_Item_Count__c ?? 0) > 0;
        Boolean urgentPurpose = (recon.Urgent_Purpose_Open_Count__c ?? 0) > 0;
        Boolean longOpen = recon.Recon_Date__c != null && recon.Recon_Date__c.daysBetween(Date.today()) >= URGENT_DAYS;
        return hasOpen && (urgentPurpose || longOpen);
    }

    private static void increment(Map<String, Integer> counts, String key) {
        counts.put(key, (counts.get(key) ?? 0) + 1);
    }

    private static List<CountRow> toSortedRows(Map<String, Integer> counts) {
        List<CountRow> rows = new List<CountRow>();
        for (String key : counts.keySet()) {
            CountRow row = new CountRow(key, counts.get(key));
            Integer i = rows.size();
            while (i > 0 && rows[i - 1].value < row.value) {
                i--;
            }
            if (i == rows.size()) {
                rows.add(row);
            } else {
                rows.add(i, row);
            }
        }
        return rows;
    }
}