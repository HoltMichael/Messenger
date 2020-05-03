import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import sendMessage from '@salesforce/apex/SendMessageHandler.sendMessage';
import decryptMessage from '@salesforce/apex/SendMessageHandler.decryptMessage';
import getChatHistory from '@salesforce/apex/SendMessageHandler.getChatHistory';
import shareContent from '@salesforce/apex/SendMessageHandler.shareContent';
import postToChatter from '@salesforce/apex/SendMessageHandler.postToChatter';
import setChatRead from '@salesforce/apex/SendMessageHandler.setChatRead';
import FORM_FACTOR from '@salesforce/client/formFactor';

export default class ChatWindow extends LightningElement {
    @api recipientName;
    @api recipientId;
    @api activeUsersName;
    @api userId;
    //Future: Introduce threads within chats.
    //@track currentThread;
    //chatText is an array holding information associated with each text output to the screen
    @track chatText = [];
    //selectedText is an array holding those messages which have been selected to be sent to Chatter
    @track selectedText = [];
    //selectedRecord holds the ID of the record to post chatter messages to
    @track selectedRecord;
    @track windowHeight;
    @track muteIcon = "utility:volume_off";
    @track mute = false;
    @track showUploadModal = false;
    @track showFullHistoryModal = false;
    @track showChatterModal = false;
    @track loading = false;
    @track selectForChatter = false;
    @track menuShrunk = false
    @track textBoxHeight='height:25rem';
    formFactor = FORM_FACTOR;

    isSmall = (this.formFactor == 'Small');
    
    
    /*
        connectedCallback
        Execute as soon as the component renders, to pull in the chat history with this user
    */
    connectedCallback(){
        this.getChatHistory(50);
        this.setChatRead();
        if(this.formFactor == 'Small'){
            this.textBoxHeight = 'height:32rem';
        }
    }

    /*
        handleKeyPress
        Capture when a user presses enter, in order to send the message
    */
    handleKeyPress(event){
        if(event.code === 'Enter'){
            let trimmedString = event.target.value.substring(0, event.target.value.length - 11); //Remove <p><br></p> from the string to be sent, added by the last 'Enter' keypress
            this.sendMessage(trimmedString);
            this.template.querySelector("lightning-input-rich-text").value = '';
        }
    }

    /*
        setChatRead
        Set the chat messages within this window as "Read"
    */
   setChatRead(){
    setChatRead({userId: this.recipientId})
        .then(result => {
            if(result!='Success'){
                this.showToastNoStrip('Something went wrong',result,'error');
            }
        })
        .catch(error => {
            this.showToastNoStrip('Something went wrong',error.body.message,'error');
        })
    }

    /*
        sendMessageForMobile
        We have a button on the mobile app, rather than pressing enter
        So respond to the button press instead
    */
    sendMessageForMobile(){
        this.sendMessage(this.template.querySelector("lightning-input-rich-text").value);
        this.template.querySelector("lightning-input-rich-text").value = '';
    }

    /*
        loadFullChatHistory
        Closes the full chat history modal 
        Sends a request to pull back a number of records, depending on the option selected by the user
        Typically, this is 300 or 50,000
    */
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
            })
            .catch(error => {
                this.showToastNoStrip('Something went wrong',error.body.message,'error');
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
            var cls = '';
            if(msg.senderId == this.userId){
                cls = 'my-message both-message slds-float_right';
            }else{
                cls = 'their-message both-message slds-float_left';
            }
            this.chatText.push({message: msg.message, senderName: msg.senderName, timestamp: msg.timestamp, cls: cls, messageId: msg.messageId});
        });
        //Scroll to the bottom of the div, waiting for the div to actually contain the chat first
        this.delayTimeout = setTimeout(() => {
            this.scrollToBottom();
        }, 100);
        this.loading = false;
    }

    /*
        handleChatSelect
        Adds selected chat messages to an array "SelectedText", when the user is in the "send to chatter" mini-menu
        Removes selected chat messages from the array if they're already in it
        Colours the messages in a slightly darker hue of green or blue
    */
    handleChatSelect(event){
        if(this.selectForChatter){
            if(event.currentTarget.classList.contains('my-message')){
                event.currentTarget.classList.toggle('my-message-selected');
            }else if(event.currentTarget.classList.contains('their-message')){
                event.currentTarget.classList.toggle('their-message-selected');
            }
            let selectedMessage = (element) => element.messageId == event.currentTarget.dataset.targetId;

            if(this.selectedText.findIndex(selectedMessage) == -1){
                this.selectedText.push(this.chatText[this.chatText.findIndex(selectedMessage)])
            }else{
                this.selectedText.splice(this.selectedText.findIndex(selectedMessage),1);
            }
        }
    }

    /*
        clearAllSelections
        Clears all CSS from text boxes which indicated that they had been selected to be posted on Chatter
        Clears the selectedText array, so no messages are selected to be posted on Chatter
    */
    clearAllSelections(){
        this.selectedText = [];
        let mySelected = this.template.querySelectorAll('.my-message-selected');
        let theirSelected = this.template.querySelectorAll('.their-message-selected');
        mySelected.forEach(sel => {
            sel.classList.remove('my-message-selected');
        });
        theirSelected.forEach(sel => {
            sel.classList.remove('their-message-selected');
        });
    }

    /*
        scrollToBottom
        Scrolls to the bottom of the chat window div
    */
    scrollToBottom(){
        let winheight = this.template.querySelector('.slds-p-around_xxx-small').scrollHeight;
        this.template.querySelector('.slds-p-around_xxx-small').scrollTop=winheight;
    }

    /*
        scrollToTop
        Scrolls to the top of the chat window div
    */
    scrollToTop(){
        this.template.querySelector('.slds-p-around_xxx-small').scrollTop=0;
    }

    /*
        decryptMessage
        Called by parent component, messenger.
        Passes the inbound encrypted text String and passes to Apex to be decrypted
        Apex applies timestamps and returns decrypted message for output to screen.
        Prompts user with toast, if user hasn't muted notifications
    */
    @api
    decryptMessage(message, sender, fromName, messageId) {
        decryptMessage({ msg: message, snd: sender })
            .then(result => {
                    let fullMessage = [{message: result.message, senderName: fromName, senderId: sender, timestamp: result.timestamp, messageId: messageId}];
                    this.displayMessage(fullMessage);
                if(!this.mute && sender != this.userId){
                    this.showToast(result.message);
                }
                this.scrollToBottom();
            })
            .catch(error => {
                this.showToastNoStrip('Something went wrong',error,'error');
            });
    }

    /*
        handleFileUpload
        Display message to user informing them of the file they have shared
        Provide link to doc (would like to use file-preview but only available in Aura)
        Call function to share file with user in Apex
    */
    handleFileUpload(event){
        let fileIds = [];
        let msg = this.activeUsersName + ' sent the following file(s): \r\n';
        event.detail.files.forEach(file => {
            fileIds.push(file.documentId);
            msg += file.name +': ' + window.location.origin + '/' + file.documentId + '\r\n'; 
        });

        this.shareContent(fileIds, msg);
    }

    /*
        shareContent
        Content being sent to the recipient will not be visible to them, as they don't have access.
        Call to Apex to share the content with the recipient using ContentDocumentLink
    */
    shareContent(ids, msg){
        shareContent({userOrGroupId: this.recipientId, documentIds: ids})
            .then(result => {
                this.sendMessage(msg);
            })
            .catch(error => {
                this.showToastNoStrip('Something went wrong',error.body.message,'error');
            })
    }

    /*
        showToast
        Strips the message of any HTML tags that are included within the rich text output
        Fires toast to user with stripped contents.
    */
    showToast(msg) {
        let strippedMsg = msg.replace(/(<([^>]+)>)/ig,"");
        const event = new ShowToastEvent({
            title: this.recipientName,
            message: strippedMsg,
        });
        this.dispatchEvent(event);
    }

    /*
        showToastNoStrip
        Doesn't strip any of the messages of characters before displaying the received message
        
    */
   showToastNoStrip(title, msg, error) {
    const event = new ShowToastEvent({
        title: title,
        message: msg,
        variant: error
    });
    this.dispatchEvent(event);
}

    /*
        sendMessage
        Passes all relevant information to the Apex method to handle the sending of the message via a platform event
    */
    sendMessage(message) {       
        sendMessage({ message: message, recipientId: this.recipientId, senderId: this.userId, name: this.activeUsersName })
            .then(result => {
                if(result != 'Success'){
                    this.showToast(result);
                }
            })
            .catch(error => {
                this.showToastNoStrip('Something went wrong',error.body.message,'error');
            });
    }


    /*
        postToChatter
        Get all of the IDs of all of the messages to be posted to Chatter
        Pass all messages to Apex, Apex handles the posting of the messages
        in the context of the user who sent the message.
    */
    postToChatter(){
        let chatIds = this.selectedText.map(x => x.messageId);
        if(this.selectedRecord == null){
            this.selectedRecord = this.userId;
        }
        postToChatter({chatIds: chatIds, recordId: this.selectedRecord})
            .then(result =>{
                this.showToast(result);
                this.toggleSelectForChatter();
                this.toggleChatterModal();
            })
            .catch(error => {
                this.showToastNoStrip('Something went wrong',error.body.message,'error');
            });
    }

    /*
        toggleShrinkMenu
        Fired when either of the 2 buttons are pressed to expand or hide the menu buttons
    */
    toggleShrinkMenu(event){
        this.menuShrunk = !this.menuShrunk;
        event.currentTarget.classList.toggle('rotate-180');
    }


    /*
        handleSelectedRecord
        Fires when child component "recordLookup" has a record selected within it
    */
    handleSelectedRecord(event){
        this.selectedRecord = event.detail.recordId;
    }

    /*
        toggleSelectForChatter
        Displays or hides the mini-menu for selecting a record to associate a Chatter post with
    */
    toggleSelectForChatter(){
        this.selectForChatter = !this.selectForChatter;
        if(this.selectForChatter == false){
            this.clearAllSelections();
        }
    }

    /*
        toggleChatterModal
        Displays or hides the confirmation modal, which appears prior to posting on Chatter
    */
    toggleChatterModal(){
        this.showChatterModal = !this.showChatterModal;
    }
    
    /*
        toggleUploadModal
        Displays or hides the modal window for uploading files
    */
    toggleUploadModal(){
        this.showUploadModal = !this.showUploadModal;
    }

    /*
        toggleFullHistory
        Displays or hides the modal window which allows users to pull in many more records
    */
    toggleFullHistory(){
        this.showFullHistoryModal = !this.showFullHistoryModal;
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