import { LightningElement, track, wire } from 'lwc';

export default class Messenger extends LightningElement {
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
    chatChosen=false;
    
    toggleFocus(event){
        console.log(event.currentTarget.id);
        this.template.querySelector('.focus-thread').classList.remove('focus-thread');
        event.currentTarget.classList.add('focus-thread');
        this.currentThread = event.currentTarget.id;
    }
}