/**
 * Domain class for the High_Usage_Alert__c SObjectType
 * Created by byarsawi on 5/9/2018.
 **/
global class HighUsageAlerts extends Framework.Domain {

    public HighUsageAlerts(List<HighUsageAlert__c> sObjectList) {
        super(sObjectList);
    }

    global class Constructor implements Framework.Domain.DomainConstructor {
        global Framework.Domain construct(List<SObject> sObjectList) {
            return new HighUsageAlerts(sObjectList);
        }
    }

    public override void applyDefaults() {
        Framework.Log.push(HighUsageAlerts.class.getName(),'applyDefaults');
        //High_Usage_AlertService.setDefaults((HighUsageAlert__c []) records);
        Framework.Log.pop();
    }

    public override void beforeInsert() {
        Framework.Log.push(HighUsageAlerts.class.getName(),'beforeInsert');
        Framework.Log.pop();
    }

    public override void afterInsert() {
        Framework.Log.push(HighUsageAlerts.class.getName(),'afterInsert');
        Framework.Log.pop();
    }

    public override void beforeUpdate(Map<Id,SObject> oldMap) {
        Framework.Log.push(HighUsageAlerts.class.getName(),'beforeUpdate');
        Framework.Log.pop();
    }

    public override void afterUpdate(Map<Id,SObject> oldMap) {
        Framework.Log.push(HighUsageAlerts.class.getName(),'afterUpdate');
        Framework.Log.pop();
    }

    public override void validate() {
        Framework.Log.push(HighUsageAlerts.class.getName(),'validate');
        Framework.Log.pop();
    }

    public override void validate(Map<Id,SObject> oldMap) {
        Framework.Log.push(HighUsageAlerts.class.getName(),'validate');
        Framework.Log.pop();
    }
}