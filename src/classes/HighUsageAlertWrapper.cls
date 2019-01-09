/**
 * Created by byarsawi on 5/14/2018.
 */

global class HighUsageAlertWrapper {

    public Boolean isSelected { get; set; }
    public High_Usage_Alert__c theCase { get; set; }
    public List<SelectOption> actionCodes { get; set; }

    public HighUsageAlertWrapper() {
        isSelected = false;
    }

}