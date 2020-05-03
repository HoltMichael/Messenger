/*
    CustomMetadataCallback
    Author: Michael Holt
    Date: 25th April 2020

    Class to allow custom metadata to be inserted. Used on install by the EncryptionKeyGenerator Class.
*/

public class CustomMetadataCallback implements Metadata.DeployCallback {
    public void handleResult(Metadata.DeployResult result,
                             Metadata.DeployCallbackContext context) {
        if (result.status == Metadata.DeployStatus.Succeeded) {
        } else {
            // Deployment was not successful
        }
    }
}