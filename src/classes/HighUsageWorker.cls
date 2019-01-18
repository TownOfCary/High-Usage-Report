/**
 * Created by byarsawi on 5/14/2018.
 */

global class HighUsageWorker {

    public Id userId { get; set; }
    public String userName { get; set; }
    public Map<String, Integer> numCases { get; set; }
    public Boolean isSelected { get; set; }

    public HighUsageWorker() {
        userId = null;
        userName = null;
        numCases = new Map<String, Integer>();
        isSelected = false;
    }

    public HighUsageWorker(Id uID, String name, Map<String, Integer> numCasesMap) {
        userId = uID;
        userName = name;
        numCases = numCasesMap;
        isSelected = false;
    }

    public Integer getTotalCases() {
        Integer result = 0;
        for (String key : numCases.keySet()) {
            result += numCases.get(key);
        }
        return result;
    }

}