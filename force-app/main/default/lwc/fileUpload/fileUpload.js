import { LightningElement, api, track } from 'lwc';

export default class fileUpload extends LightningElement {
    @api uploadTargetId;
    @track fileUploaded = false;
    @track fileNames = '';

    closeModal(){
        this.dispatchEvent(new CustomEvent('close'));
        this.resetWindow();
    }

    resetWindow(){
        this.fileNames = '';
        this.fileUploaded = false;
    }

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