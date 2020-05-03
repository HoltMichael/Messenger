import { LightningElement, api, track } from 'lwc';

export default class fileUpload extends LightningElement {
    @api uploadTargetId;
    @track fileUploaded = false;
    @track fileNames = '';

    /*
        closeModal
        Tell the ChatWindow component to close the modal.
        Reset the properties in this component
    */
    closeModal(){
        this.dispatchEvent(new CustomEvent('close'));
        this.resetWindow();
    }

    /*
        resetWindow
        Reset the properties in this component
    */
    resetWindow(){
        this.fileNames = '';
        this.fileUploaded = false;
    }

    /*
        handleUploadFinished
        Once a file has been uploaded, send the information about those files to the parent
        chatWindow component. ChatWindow will share uploaded files with relevant users and then
        send the message to the recipient(s) to link them to the message
        (Lightning:FileUpload only available in Aura)
    */
    handleUploadFinished(event) {
        this.fileUploaded = true;
        const uploadedFiles = event.detail.files;
        uploadedFiles.forEach(file => {
            this.fileNames += file.name + '\r\n ';
        });
        this.fileNames = this.fileNames.substring(0, this.fileNames.length - 2); //removing trailing space and comma

        const fileEvent = new CustomEvent('fileupload', {
            detail: { files: uploadedFiles}
        });
        this.dispatchEvent(fileEvent);
    }
}