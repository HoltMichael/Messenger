import { LightningElement, wire } from 'lwc';
import findUsers from '@salesforce/apex/MessengerUtils.findUsers';
import findGroups from '@salesforce/apex/MessengerUtils.findGroups';

const DELAY = 300;

export default class UserSearch extends LightningElement {
    searchKey = '';

    @wire(findUsers, { searchKey: '$searchKey' })
    users;

    @wire(findGroups, { searchKey: '$searchKey' })
    groups;

    handleKeyChange(event) {
        console.log('here');
        window.clearTimeout(this.delayTimeout);
        const searchKey = event.target.value;

        this.delayTimeout = setTimeout(() => {
            this.searchKey = searchKey;
        }, DELAY);
    }
}