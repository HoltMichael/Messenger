import { LightningElement, api, track } from 'lwc';

export default class ChatWindow extends LightningElement {
    @api recipientName;
    @api recipientId;
    @track threadList = [
        {
            Id:'001',
            Name:'Thread 1'
        },
        {
            Id:'002',
            Name:'Thread 2'
        }
    ];
    currentThread;


    toggleFocus(event){
        this.template.querySelector('.focus-thread').classList.remove('focus-thread');
        event.currentTarget.classList.add('focus-thread');
        this.currentThread = event.currentTarget.id;
    }
}