---
title: "Enrich and Validate Phone Number Data in Google Forms and Sheets With Twilio"
date: 2022-03-13T17:18:31-07:00
draft: false
hidden: true
---

Way back in 2016 we wrote an article about [Validating Phone Numbers in Google Spreadsheets](https://www.twilio.com/blog/2016/03/how-to-look-up-and-verify-phone-numbers-in-google-spreadsheets-with-javascript.html). Well it’s been a few years and validating phone numbers is still incredibly relevant. This time around though let’s talk about how you might allow user submissions via a Google Form and automatically populate the resulting Google Spreadsheet with lots of useful information about the phone number the user provided including whether or not it is valid.

Similarly to the previous article, we will use the Twilio Lookup API to populate the phone number’s type, carrier, country code, formatted phone number, as well as the api status (I.E. whether or not the phone number was found).

We will use Google Apps Script, which is a language very similar to JavaScript, in order to query the Twilio API and gather the additional information about the phone number. After we have the information about the number we will update the spreadsheet with the data.

## Get a Twilio account if you don’t have one

If you don’t have a Twilio account, [sign up here](http://twilio.com/try-twilio). A free trial account gives you $15.50 in Twilio credit to play with. At $0.005 per lookup, you can look up 3,100 phone numbers before having upgrading your account.

Once you’re signed in, go to your [dashboard](https://console.twilio.com/) and you’ll be able to see your Account SID and Auth Token. You’ll need both these in order to make Twilio Lookup API calls later.

![dashboard:credentials.png](Enriching%20%206845c/dashboardcredentials.png)

## Setup the data collection form

Now, let’s go ahead and setup the form that we’ll be using to collect the users information. This will be a pretty simple form where we will just ask for the users name and phone number. The rest of the information will be populated by Twilio.

First go to [Google Forms](https://docs.google.com/forms) and create a new blank form. Give it a name and description if you’d like. Finally, let’s create the two fields we will be using. Name and Phone Number both of which will be a short answer field type.

![Untitled](Enriching%20%206845c/Untitled.png)

At this point Google Forms has really taken care of us. We have a form that we can make public and it will automatically publish the responses to a Google Sheet for tracking. We can turn our Google Form up to 11 by incorporating it with Twilio.

In order to get to the Google Sheet click on “Responses” and then click the Google Sheets icon in the top right. Select “Create a new spreadsheet” and you’ll be taken to a spreadsheet where your responses are being recorded.

![go to google sheets.png](Enriching%20%206845c/go_to_google_sheets.png)

If you want to see it in action go back to your Google Form and click the eyeball icon in the top right. You’ll be taken to a preview link for your form, you can fill it out, and see your response is recorded in the Google Sheet we just created.

## Make our Google Sheet a little smarter

Google uses a language called [Google Apps Script](https://developers.google.com/apps-script) to allow users, like us, to enhance and customize their G Suite Apps. In our case we will use Google Apps Script in order to automatically populate a few extra columns of phone number information for each form submission. First let’s add the additional columns that we’ll need. Your sheet should already have a Timestamp, Name, and Phone Number column. Let’s also add Status, Phone Type, Carrier, Country Code, and National Format. These columns will be populated from the results of the Twilio API.

It’s time to get to the good stuff. Go to Extensions and click on Apps Script in order to add our api call to Twilio.

![go to google apps script.png](Enriching%20%206845c/go_to_google_apps_script.png)

You’ll be taken to a nearly empty editor where we can work on our code. One thing to note is that this Apps Script is already linked to our Google Sheet and Google Form. So when we add the trigger to the Apps Script it will automatically be called by only the Google Sheet and Google Form that we created for our awesome SMS service.

First, replace all the code in the editor with the following snippet. We will dig into what the code is actually doing in a moment.

```jsx
function lookup(event) {
  const { namedValues, range } = event;
  const phoneNumber = namedValues["Phone Number"];
  const row = range.rowStart;
  const sheet = SpreadsheetApp.getActiveSheet();

  try {
    const numberResponse = lookupNumber(phoneNumber);
    updateSpreadsheet(sheet, numberResponse, row);
  } catch (err) {
    Logger.log(err);
    sheet.getRange(row, 4).setValue('lookup error');
  }
}

function lookupNumber(phoneNumber) {
    var lookupUrl = "https://lookups.twilio.com/v1/PhoneNumbers/" + phoneNumber + "?Type=carrier";

    var options = {
        "method" : "get"
    };

    options.headers = {
        "Authorization" : "Basic " + Utilities.base64Encode("<AccountSID>:<Auth Token>")
    };

    var response = UrlFetchApp.fetch(lookupUrl, options);
    var data = JSON.parse(response);
    Logger.log(data);
    return data;
}

function updateSpreadsheet(sheet, numberResponse, row) {
  if (numberResponse['status'] == 404) {
    sheet.getRange(row, 4).setValue("not found");
  } else {
    sheet.getRange(row, 4).setValue("found");
    sheet.getRange(row, 5).setValue(numberResponse['carrier']['type']);
    sheet.getRange(row, 6).setValue(numberResponse['carrier']['name']);
    sheet.getRange(row, 7).setValue(numberResponse['country_code']);
    sheet.getRange(row, 8).setValue(numberResponse['national_format']);
  }
}

function testLookup() {
  lookupNumber("16502065555");
}
```

Notice the `testLookup` function at the bottom there. We can use that function in order to manually run our code and see the results. Replace the <Account Sid> and <Auth Token> placeholders with those that you copied from your Twilio dashboard earlier. Save the script by clicking the floppy disk icon, pick `testLookup` from the dropdown, and click run.

You’ll be shown a dialog prompt that is asking you to review permissions before you can execute your script.

![Screen Shot 2022-02-09 at 10.00.50 PM.png](Enriching%20%206845c/Screen_Shot_2022-02-09_at_10.00.50_PM.png)

You can accept most of the prompts but since your apps script is unverified you’ll be presented with a huge warning screen. You’ll need to click the “Show advanced” button and then the “Proceed to <Your Project Name> (unsafe)” button to continue. I didn’t rename my Apps Script project so mine says “Proceed to Untitled (unsafe)”. You’ll only have to do this once and you’ll be able to run your script as many times as you want.

![Screen Shot 2022-02-09 at 10.01.13 PM.png](Enriching%20%206845c/Screen_Shot_2022-02-09_at_10.01.13_PM.png)

The script should have run now but if not click the “Run” button again. If everything is working correctly then you should see something similar to the image below.

![Untitled](Enriching%20%206845c/Untitled%201.png)

Look at all the cool data we get back from the Twilio Lookup API! You can see that I picked the Google Customer Support phone number as the example phone number. We see the country code, formatted phone number, carrier name, etc.

The final piece is to setup the triggers so that when a form is submitted the data from that lookup request will be saved into the Google Sheet containing our responses.

On the bar on the left click on the clock icon. This area is for setting up triggers for our Google Form and Google Sheet. We can setup [all sorts of triggers](https://developers.google.com/apps-script/guides/triggers#available_types_of_triggers) but the one that we are interested in is onFormSubmit. This way whenever a user successfully submits a form Google Apps Script will automatically run the function we chose.

Click the “Add Trigger” button and fill out the pop up as follows.

![Screen Shot 2022-02-09 at 10.09.40 PM.png](Enriching%20%206845c/Screen_Shot_2022-02-09_at_10.09.40_PM.png)

The two most important things here are that you pick the correct function to run, in our case `lookup` and that the event type is set to “On form submit”. You may have to go through the hoops to give permissions again after you click “Save”. If you are successful you should see that your triggers look the same as the following image.

![Untitled](Enriching%20%206845c/Untitled%202.png)

Most importantly the event is “From spreadsheet - On form submit” and the function is our `lookup` function.

At this point we have a fully functional form that is populating those additional columns we added earlier! Go back to your form, click the preview eye, and fill out a response. If you use your personal phone number you should see some familiar information show up in those extra columns. In my case I’ll use the Google phone number again but you can see that the additional columns are populated with Google’s information! Huzzah we’ve done it!

![Untitled](Enriching%20%206845c/Untitled%203.png)

## Deep dive

Now we can spend a little bit of time digging into that code we pasted in earlier. The first function is the `lookup` function which is called by the trigger we setup earlier.

```jsx
function lookup(event) {
  const { namedValues, range } = event;
  const phoneNumber = namedValues["Phone Number"];
  const row = range.rowStart;
  const sheet = SpreadsheetApp.getActiveSheet();

  try {
    const numberResponse = lookupNumber(phoneNumber);
    updateSpreadsheet(sheet, numberResponse, row);
  } catch (err) {
    Logger.log(err);
    sheet.getRange(row, 4).setValue('lookup error');
  }
}
```

The [event argument](https://developers.google.com/apps-script/guides/triggers/events) that gets passed in is full of all sorts of information about the new row that was added to the Google Sheet. It contains things like which row was updated, the range of columns that were updated, and the values that were put into those columns. In our case we are the most interested in the phone number value and row. We get those values from `event.range.rowStart` and `event.namedValues["Phone Number"]`. After that we will pass the phone number to the lookupNumber function and if that is successful we will update the spreadsheet with the data returned from the Twilio API.

The next function is the lookupNumber function which does the actual Twilio Lookup API call.

```jsx
function lookupNumber(phoneNumber) {
    var lookupUrl = "https://lookups.twilio.com/v1/PhoneNumbers/" + phoneNumber + "?Type=carrier";

    var options = {
        "method" : "get"
    };

    options.headers = {
        "Authorization" : "Basic " + Utilities.base64Encode("<Account Sid>:<Auth Token>")
    };

    var response = UrlFetchApp.fetch(lookupUrl, options);
    var data = JSON.parse(response);
    Logger.log(data);
    return data;
}
```

Here you see that we are building the URL and inserting the phoneNumber argument into that url. The Twilio Lookup API uses a simple get request in order to do the lookup. Next, we build up the options for the request with the method set to get and the Authorization header set with our account sid and auth token. Finally we make the request, decode it as JSON, log it for debugging purposes, and return it if successful. If there is an error at any point in this function an error will be thrown and our lookup function will handle that by writing a failed status to the Google Sheet. If you’d like to know more about how the UrlFetchApp works or how you can customize it to work with other requests you can look at Google’s documentation for that class [here](https://developers.google.com/apps-script/reference/url-fetch/url-fetch-app).

Finally, we need to take the data we received from the API request and populate the spreadsheet with it.

```jsx
function updateSpreadsheet(sheet, numberResponse, row) {
  if (numberResponse['status'] == 404) {
    sheet.getRange(row, 4).setValue("not found");
  } else {
    sheet.getRange(row, 4).setValue("found");
    sheet.getRange(row, 5).setValue(numberResponse['carrier']['type']);
    sheet.getRange(row, 6).setValue(numberResponse['carrier']['name']);
    sheet.getRange(row, 7).setValue(numberResponse['country_code']);
    sheet.getRange(row, 8).setValue(numberResponse['national_format']);
  }
}
```

We sent the active Google Sheet so we can update the columns, the numberResponse which contains the data from the Twilio Lookup API request, and the row number of the new data to this function. We first detect if we got a 404 meaning that the number was not found and write that to the sheet. Otherwise, we got a successful response and we can write the rest of the data to the appropriate column numbers that match our sheet. Keep in mind that if we add or remove any columns from the Google Form that we will have to come back and update those column numbers to match.

## Conclusion

In this article we setup a Google Form, Google Sheet, and Google Apps Script to receive phone numbers from users and enrich that data with data from the Twilio Lookup API. We walked through the process step by step and built our own phone number collection form by adding Google Apps Script and triggers to our form to run the lookup function on every form submission. Finally, we dove deep into the code to explain exactly how to make API requests to the Twilio API and use the Google Sheets functions for writing that data back into the Google Sheet that collects the form responses.

I have you’ve enjoyed this article and I especially hope you’ve learned something!

## Publisehd To
- [https://www.twilio.com/blog/enrich-validate-phone-number-data-google-forms-sheets](https://www.twilio.com/blog/enrich-validate-phone-number-data-google-forms-sheets)
