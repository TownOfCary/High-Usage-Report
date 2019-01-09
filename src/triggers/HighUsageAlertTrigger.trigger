/**
 * Created by byarsawi on 5/15/2018.
 */

trigger HighUsageAlertTrigger on High_Usage_Alert__c (before insert, before update) {
    Framework.Dispatcher.dispatchTrigger();
}