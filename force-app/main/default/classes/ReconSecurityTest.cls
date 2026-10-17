/**
 * 입출금 대조 앱 권한 테스트.
 * 대조 담당(Bank_Recon_User), 처리 담당(Recon_Handler), 팀장(Recon_Manager)이
 * 할 수 있는 일과 막히는 일을, 그리고 운영팀이 아닌 부서(재무팀·IT팀)는 권한 세트가 있어도 기록을 못 보는지를 사용자 권한(USER_MODE)으로 직접 시도해 확인한다.
 */
@IsTest
private class ReconSecurityTest {
  static User makeUser(String alias, String permSet, String role) {
    Profile platform = [
      SELECT Id
      FROM Profile
      WHERE
        UserLicense.Name = 'Salesforce Platform'
        AND Name IN ('Standard Platform User', '표준 플랫폼 사용자')
      LIMIT 1
    ];
    User u = new User(
      LastName = alias,
      Alias = alias,
      Email = alias + '@example.com',
      Username = alias +
        '.' +
        Crypto.getRandomInteger() +
        '@recon-test.example.com',
      ProfileId = platform.Id,
      UserRoleId = [SELECT Id FROM UserRole WHERE DeveloperName = :role]
      .Id,
      TimeZoneSidKey = 'Asia/Seoul',
      LocaleSidKey = 'ko_KR',
      LanguageLocaleKey = 'ko',
      EmailEncodingKey = 'UTF-8'
    );
    insert u;
    insert new PermissionSetAssignment(
      AssigneeId = u.Id,
      PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = :permSet]
      .Id
    );
    return u;
  }

  static Map<String, User> makeUsers() {
    Map<String, User> users = new Map<String, User>();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      users.put('preparer', makeUser('prep', 'Bank_Recon_User', 'Recon_Ops'));
      users.put('handler', makeUser('hand', 'Recon_Handler', 'Recon_Ops'));
      users.put('manager', makeUser('mgr', 'Recon_Manager', 'Recon_Ops_Lead'));
      users.put('outsider', makeUser('it', 'Bank_Recon_User', 'Recon_IT'));
      users.put('finance', makeUser('fin', 'Recon_Handler', 'Recon_Finance'));
    }
    return users;
  }

  static Recon_Item__c makeItem() {
    Daily_Recon__c recon = new Daily_Recon__c(
      Recon_Date__c = Date.today(),
      Recon_Account__c = '패런트',
      System_Balance__c = 1000,
      Bank_Balance__c = 1300
    );
    insert recon;
    Recon_Item__c item = new Recon_Item__c(
      Daily_Recon__c = recon.Id,
      Side__c = '통장에만',
      Amount__c = 300,
      Cause__c = '시스템 미반영'
    );
    insert item;
    return item;
  }

  /** 사용자의 권한 세트에 '대조 입력' 커스텀 권한(홈 마법사 표시 조건)이 있는지 */
  static Boolean canUseWizard(User u) {
    return [
        SELECT COUNT()
        FROM SetupEntityAccess
        WHERE
          SetupEntityId IN (
            SELECT Id
            FROM CustomPermission
            WHERE DeveloperName = 'Recon_Entry'
          )
          AND ParentId IN (
            SELECT PermissionSetId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :u.Id
          )
      ] > 0;
  }

  static Boolean isBlocked(String op, SObject record) {
    try {
      if (op == 'insert') {
        Database.insert(record, AccessLevel.USER_MODE);
      } else if (op == 'update') {
        Database.update(record, AccessLevel.USER_MODE);
      } else {
        Database.delete(record, AccessLevel.USER_MODE);
      }
      return false;
    } catch (Exception e) {
      return true;
    }
  }

  @IsTest
  static void preparerCreatesReconsButCannotDelete() {
    Map<String, User> users = makeUsers();
    Recon_Item__c item = makeItem();

    Assert.isTrue(
      canUseWizard(users.get('preparer')),
      '대조 담당은 마법사를 쓸 수 있다'
    );
    System.runAs(users.get('preparer')) {
      Daily_Recon__c recon = new Daily_Recon__c(
        Recon_Date__c = Date.today(),
        Recon_Account__c = '체킹',
        System_Balance__c = 500
      );
      Assert.isFalse(
        isBlocked('insert', recon),
        '대조 담당은 대조를 만들 수 있다'
      );
      Assert.isFalse(
        isBlocked('update', new Recon_Item__c(Id = item.Id, Amount__c = 310)),
        '대조 담당은 금액을 고칠 수 있다'
      );
      Assert.isTrue(
        isBlocked('delete', new Recon_Item__c(Id = item.Id)),
        '대조 담당도 삭제는 못 한다'
      );
      Assert.isTrue(
        isBlocked('delete', new Daily_Recon__c(Id = recon.Id)),
        '대조 기록은 지울 수 없다'
      );
    }
  }

  @IsTest
  static void handlerResolvesButCannotChangeAmounts() {
    Map<String, User> users = makeUsers();
    Recon_Item__c item = makeItem();

    Assert.isFalse(
      canUseWizard(users.get('handler')),
      '처리 담당에게는 마법사가 안 보인다'
    );
    System.runAs(users.get('handler')) {
      Assert.isTrue(
        isBlocked('update', new Recon_Item__c(Id = item.Id, Amount__c = 0)),
        '처리 담당은 금액을 못 고친다'
      );
      Assert.isTrue(
        isBlocked(
          'update',
          new Daily_Recon__c(Id = item.Daily_Recon__c, System_Balance__c = 1300)
        ),
        '처리 담당은 잔액을 못 고친다'
      );
      Assert.isTrue(
        isBlocked(
          'insert',
          new Recon_Item__c(
            Daily_Recon__c = item.Daily_Recon__c,
            Side__c = '통장에만',
            Amount__c = 1
          )
        ),
        '처리 담당은 항목을 못 만든다'
      );
      Assert.isTrue(
        isBlocked('delete', new Recon_Item__c(Id = item.Id)),
        '처리 담당은 항목을 못 지운다'
      );
      Assert.isFalse(
        isBlocked(
          'update',
          new Recon_Item__c(
            Id = item.Id,
            Resolved__c = true,
            Resolution_Note__c = '시스템 반영 완료'
          )
        ),
        '처리 담당은 처리 내용과 해결 체크는 할 수 있다'
      );
    }
    Assert.isTrue(
      [SELECT Resolved__c FROM Recon_Item__c WHERE Id = :item.Id].Resolved__c
    );
  }

  @IsTest
  static void managerOnlyReads() {
    Map<String, User> users = makeUsers();
    Recon_Item__c item = makeItem();

    Assert.isFalse(
      canUseWizard(users.get('manager')),
      '팀장에게는 마법사가 안 보인다'
    );
    System.runAs(users.get('manager')) {
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Recon_Item__c WITH USER_MODE],
        '팀장은 항목을 볼 수 있다'
      );
      Assert.isTrue(
        isBlocked(
          'update',
          new Recon_Item__c(Id = item.Id, Resolved__c = true)
        ),
        '팀장은 해결 체크를 못 한다'
      );
      Assert.isTrue(
        isBlocked(
          'update',
          new Daily_Recon__c(Id = item.Daily_Recon__c, Bank_Balance__c = 1000)
        ),
        '팀장은 잔액을 못 고친다'
      );
      Assert.isTrue(
        isBlocked('delete', new Daily_Recon__c(Id = item.Daily_Recon__c)),
        '팀장은 대조를 못 지운다'
      );
    }
  }

  @IsTest
  static void otherTeamsCannotSeeRecons() {
    Map<String, User> users = makeUsers();
    Recon_Item__c item = makeItem();

    // 실수로 권한 세트를 받았더라도, 운영팀이 아니면 기록이 안 보인다
    for (String key : new List<String>{ 'outsider', 'finance' }) {
      System.runAs(users.get(key)) {
        Assert.areEqual(
          0,
          [SELECT COUNT() FROM Daily_Recon__c WITH USER_MODE],
          key + ': 대조를 볼 수 없다'
        );
        Assert.areEqual(
          0,
          [SELECT COUNT() FROM Recon_Item__c WITH USER_MODE],
          key + ': 항목을 볼 수 없다'
        );
        Assert.isTrue(
          isBlocked(
            'update',
            new Recon_Item__c(Id = item.Id, Resolved__c = true)
          ),
          key + ': 항목을 고칠 수 없다'
        );
      }
    }
  }
}
