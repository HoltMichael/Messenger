import { LightningElement, wire, track, api } from 'lwc';
import findUsers from '@salesforce/apex/MessengerUtils.findUsers';
import findGroups from '@salesforce/apex/MessengerUtils.findGroups';

const DELAY = 300;

export default class UserSearch extends LightningElement {
    searchKey = '';
    users = [];
    numUsers;
    groups = [];
    numGroups;

    get showUsers(){
        return this.numUsers > 0;
    }

    get showGroups(){
        return this.numGroups > 0;
    }

    handleSelect(event){
        event.preventDefault();
        const selectEvent = new CustomEvent('select', {
            detail: { userId: () => event.currentTarget.dataset.userId, userName: ()=> event.currentTarget.dataset.userName}
        });
        this.dispatchEvent(selectEvent);
    }

    get userHeight(){
        if(this.users.data){
            var height = 10;
            if(this.numUsers < 10){
                height = this.numUsers + 1;
            }
            if(height > 10){
                height = 10;
            }
            return 'height:' + height + 'rem;width:24rem';
        }
    }

    get groupHeight(){
        console.log('here1');
        if(this.groups.data){
            var height = 10;
            if(this.numGroups < 10){
                console.log('here2');
                height = this.numGroups + 1;
            }
            if(height > 10){
                console.log('here3');
                height = 10;
            }
            console.log('here4');
            console.log(height);
            return 'height:' + height + 'rem;width:24rem';
        }
    }

    @wire(findUsers, {searchKey: '$searchKey'})
    retrieveUsers(data,error) { 
        if(data){
            this.users = data;
            if(this.users.data){
                this.numUsers = this.users.data.length;
                //this.setUserHeight();
            }
        } else if(error){
            console.log(error);   
        }
    } 

    @wire(findGroups, {searchKey: '$searchKey'})
    retrieveGroups(data,error) { 
        if(data){
            this.groups = data;
            if(this.groups.data){
                this.numGroups = this.groups.data.length;
                //this.setGroupHeight();
            }
        } else if(error){
            console.log(error);   
        }
    } 

    @wire(findGroups, { searchKey: '$searchKey' })
    groups;

    handleKeyChange(event) {
        window.clearTimeout(this.delayTimeout);
        const searchKey = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.searchKey = searchKey;
        }, DELAY);
    }
}