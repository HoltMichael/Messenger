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

    /*
        showUsers
        Set the users template to appear and show available users,
        so long as there are more than 0 users returned.
    */
    get showUsers(){
        return this.numUsers > 0;
    }

    /*
        showGroups
        Set the groups template to appear and show available groups,
        so long as there are more than 0 groups returned.
        Disabled for version 1
    */
    get showGroups(){
        return false;
        //return this.numGroups > 0;
    }

    /*
        handleSelect
        Stop the normal link behaviour and instead fire an event indicating which
        window has been selected. Messenger component will then add this to ChatTexts and
        create a new ChatWindow component in the UI
    */
    handleSelect(event){
        event.preventDefault();
        const selectEvent = new CustomEvent('select', {
            detail: { userId: () => event.currentTarget.dataset.userId, userName: ()=> event.currentTarget.dataset.userName, userPic: ()=> event.currentTarget.dataset.userPic}
        });
        this.dispatchEvent(selectEvent);
    }

    /*
        userHeight
        Change the height of the "user" view depending on the number of users returned
    */
    get userHeight(){
        if(this.users.data){
            var height = 30;
            if(this.numUsers < 30){
                height = this.numUsers + 1;
            }
            if(height > 30){
                height = 30;
            }
            return 'height:' + height + 'rem;width:24rem';
        }
    }

    /*
        userHeight
        Change the height of the "group" view depending on the number of groups returned
    */
    get groupHeight(){
        if(this.groups.data){
            var height = 10;
            if(this.numGroups < 10){
                height = this.numGroups + 1;
            }
            if(height > 10){
                height = 10;
            }
            return 'height:' + height + 'rem;width:24rem';
        }
    }

    /*
        retrieveUsers
        Get the users that populate the "user" view, based on the searchkey
        entered. If searchKey is blank, a maximum of 50 users are pulled back
        based on SOQL query. Populate the number of users into the numUsers variable
        So that the height of the window can be calculated
    */
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

    /*
        Get the groups that populate the "group" view, based on the searchkey
        entered. If searchKey is blank, a maximum of 50 groups are pulled back
        based on SOQL query. Populate the number of groups into the numGroups variable
        So that the height of the window can be calculated
    */
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

    /*
        handleKeyChange
        Handle the typing of characters into the search bar and 
        set the searchKey variable accordingly, causing retrieveGroups
        and retrieveUsers to fire
    */
    handleKeyChange(event) {
        window.clearTimeout(this.delayTimeout);
        const searchKey = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.searchKey = searchKey;
        }, DELAY);
    }
}