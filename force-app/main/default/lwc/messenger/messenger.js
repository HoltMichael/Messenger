import { LightningElement, track, wire } from 'lwc';

export default class Messenger extends LightningElement {
    selectedChatId;
    selectedChatName;
    @track chatWindows = [];

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