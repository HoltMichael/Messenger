import { LightningElement, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import Id from '@salesforce/user/Id'; 


export default class Messenger extends LightningElement {
    selectedChatId;
    selectedChatName;
    @track chatWindows = [];
    @track objUser = {};
    userId = Id;
    
    // using wire service getting current user data
    @wire(getRecord, { recordId: Id, fields: ['User.FirstName', 'User.LastName', 'User.Name', 'User.Alias', 'User.IsActive'] })
    userData({error, data}) {
        if(data) {
            window.console.log('data ====> '+JSON.stringify(data));

            let objCurrentData = data.fields;

            this.objUser = {
                FirstName : objCurrentData.FirstName.value,
                LastName : objCurrentData.LastName.value,
                Name : objCurrentData.Name.value,
                Alias : objCurrentData.Alias.value,
                IsActive : objCurrentData.IsActive.value,
            }
        } 
        else if(error) {
            window.console.log('error ====> '+JSON.stringify(error))
        } 
    }

    handleSelect(event) {
        this.selectedChatId = event.detail.userId();
        this.selectedChatName = event.detail.userName();
        this.createChatWindow();
    }

    createChatWindow(){
        var chatWindow = {recipientId: this.selectedChatId, recipientName:this.selectedChatName};
        this.chatWindows.push(chatWindow);
        console.log(this.chatWindows);
    }
}