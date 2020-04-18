import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import sendMessage from '@salesforce/apex/SendMessageHandler.sendMessage';
import decryptMessage from '@salesforce/apex/SendMessageHandler.decryptMessage';
import getChatHistory from '@salesforce/apex/SendMessageHandler.getChatHistory';
import shareContent from '@salesforce/apex/SendMessageHandler.shareContent';

export default class ChatWindow extends LightningElement {
    @api recipientName;
    @api recipientId;
    @api activeUsersName;
    @api userId;
    @track currentThread;
    @track chatText = [];
    //response;
    @track mute = false;
    @track muteIcon = "utility:volume_off";
    @track windowHeight;
    @track showUploadModal = false;
    @track showFullHistoryModal = false;
    @track loading = false;
    @track showBoxes = false;
    
    /*
        connectedCallback
        Execute as soon as the component renders, to pull in the chat history with this user
    */
    connectedCallback(){
        this.getChatHistory(50);
    }

    /*
        handleKeyPress
        Capture when a user presses enter, in order to send the message
    */
    handleKeyPress(event){
        if(event.code === 'Enter'){
            var trimmedString = event.target.value.substring(0, event.target.value.length - 11); //Remove <p><br></p> from the string to be sent, added by the last 'Enter' keypress
            this.sendMessage(trimmedString);
            this.template.querySelector("lightning-input-rich-text").value = '';
        }
    }

    loadFullChatHistory(event){
        this.toggleFullHistory();
        this.getChatHistory(event.detail.numRecs);
    }

    /*
        getChatHistory
        Call Apex method to pull in the chat history with this particular user
        Not able to use @wire, due to the complexities around timezones, handled in Apex
    */
    getChatHistory(recordLimit) {
        this.loading = true;
        getChatHistory({ user1: this.userId, user2: this.recipientId, lim: recordLimit})
            .then(result => {
                this.chatText = [];
                this.displayMessage(result); 

                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
            });
    }

    /*
        displayMessage
        Handles the displaying of messages on screen. Loops through a list of message contents
        and extracts relevant info. Applies CSS styling, depending on who sent the message
        Adds messages to the chatText array and then scrolls to the bottom of the div
    */
    displayMessage(allMessageContents){
        allMessageContents.forEach(msg => {
            console.log('Progressing?');
            console.log(this.isProgressing);
            var cls = '';
            if(msg.senderId == this.userId){
                cls = 'my-message both-message slds-float_right';
            }else{
                cls = 'their-message both-message slds-float_left';
            }
            this.chatText.push({text: msg.message, senderName: msg.senderName, timestamp: msg.timestamp, class: cls, id: msg.messageId, checked: false});
        });
        //Scroll to the bottom of the div, waiting for the div to actually contain the chat first
        this.delayTimeout = setTimeout(() => {
            this.scrollToBottom();
        }, 100);
        this.loading = false;
    }

    /*
        scrollToBottom
        Scrolls to the bottom of the chat window div
    */
    scrollToBottom(){
        console.log('scrolling down');
        var winheight = this.template.querySelector('.slds-p-around_small').scrollHeight;
        this.template.querySelector('.slds-p-around_small').scrollTop=winheight;
    }

    /*

    */
    scrollToTop(){
        console.log('scrolling up');
        console.log(this.template.querySelector('.slds-p-around_small').scrollHeight);
        this.template.querySelector('.slds-p-around_small').scrollTop=0;

    }

    /*
        decryptMessage
        Called by parent component, messenger.
        Passes the inbound encrypted text String and passes to Apex to be decrypted
        Apex applies timestamps and returns decrypted message for output to screen.
        Prompts user with toast, if user hasn't muted notifications
    */
    @api
    decryptMessage(message, sender, fromName) {
        decryptMessage({ msg: message, snd: sender })
            .then(result => {
                    var fullMessage = [{message: result.message, senderName: fromName, senderId: sender, timestamp: result.timestamp}];
                    this.displayMessage(fullMessage);
                if(!this.mute && sender != this.userId){
                    this.showToast(result.message);
                }
                this.error = undefined;
                this.scrollToBottom();
            })
            .catch(error => {
                this.error = error;
            });
    }

    /*
        handleFileUpload
        Display message to user informing them of the file they have shared
        Provide link to doc (would like to use file-preview but only available in Aura)
        Call function to share file with user in Apex
    */
    handleFileUpload(event){
        var fileIds = [];
        var msg = this.activeUsersName + ' sent the following file(s): \r\n';
        event.detail.files.forEach(file => {
            fileIds.push(file.documentId);
            msg += file.name +': ' + window.location.origin + '/' + file.documentId + '\r\n'; 
        });

        this.shareContent(fileIds, msg);
        //var fileMessage = [{message: msg, senderName: this.activeUsersName, senderId: this.userId, timestamp: ''}];
        
    }

    /*
        shareContent
        Content being sent to the recipient will not be visible to them, as they don't have access.
        Call to Apex to share the content with the recipient using ContentDocumentLink
    */
    shareContent(ids, msg){
        shareContent({userOrGroupId: this.recipientId, documentIds: ids})
            .then(result => {
                console.log('done');
                this.sendMessage(msg);
            })
    }

    /*
        showToast
        Strips the message of any HTML tags that are included within the rich text output
        Fires toast to user with stripped contents.
        //TODO: Fire toast when window pops open due to inbound message
    */
    showToast(msg) {
        var strippedMsg = msg.replace(/(<([^>]+)>)/ig,"");
        const event = new ShowToastEvent({
            title: this.recipientName,
            message: strippedMsg,
        });
        this.dispatchEvent(event);
    }

    /*
        sendMessage
        Passes all relevant information to the Apex method to handle the sending of the message via a platform event
    */
    sendMessage(message) {       
        sendMessage({ message: message, thread: this.currentThread, recipientId: this.recipientId, senderId: this.userId, name: this.activeUsersName })
            .then(result => {
                var response = result;
            })
            .catch(error => {
                var error = error;
            });
    }

    toggleShowBoxes(){
        this.showBoxes = !this.showBoxes;
    }
    

    toggleUploadModal(){
        this.showUploadModal = !this.showUploadModal;
    }

    toggleFullHistory(){
        console.log(this.showFullHistoryModal);
        this.showFullHistoryModal = !this.showFullHistoryModal;
        console.log(this.showFullHistoryModal);
    }

    /*
        toggleMute
        Mutes and unmutes the notifications (toasts)
        Changes the button icon to reflect mute status
    */
    toggleMute(){
        if(this.mute){
            this.mute = false;
            this.muteIcon = "utility:volume_off";
        }else{
            this.mute = true;
            this.muteIcon = "utility:alert";
        }
    }

    /*
        closeWindow
        Fire an event to parent to get the current widnow to close
    */
    closeWindow(){
        const selectEvent = new CustomEvent('close', {
            detail: { recipientId: this.recipientId }
        });
        this.dispatchEvent(selectEvent);
    }
}