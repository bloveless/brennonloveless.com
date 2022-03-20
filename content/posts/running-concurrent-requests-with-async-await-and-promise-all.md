---
title: "Running Concurrent Requests With Async Await and Promise All"
date: 2021-05-17T12:00:00-07:00
draft: false
---

## Introduction

In this article I’d like to touch on async, await, and Promise.all in JavaScript. First, I’ll talk about concurrency vs parallelism and why we will be targeting parallelism in this article. Then, I’ll talk about how to use async and await to implement a parallel algorithm in serial and how to make it work in parallel by using Promise.all. Finally, I’ll create an example project using Salesforce’s Lightning Web Components where I will build an art gallery using Harvard’s Art Gallery API.

## Concurrency Vs Parallelism

I want to quickly touch on the difference between concurrency and parallelism. You can relate concurrency to how a single-threaded CPU processes multiple tasks. Single-threaded CPUs emulate parallelism by switching between processes quickly enough that it seems like multiple things are happening at the same time. Parallelism is when a CPU has multiple cores and can actually run two tasks at the exact same time. Another great example is this:
>  *Concurrency is two lines of customers ordering from a single cashier (lines take turns ordering); Parallelism is two lines of customers ordering from two cashiers (each line gets its own cashier). [1]*

Knowing this difference helps us consider what options we have from an algorithmic standpoint. Our goal is to make these HTTP requests in parallel. Due to some limitations in JavaScript implementation and browser variability, we don’t actually get to determine if our algorithm will be run concurrently or in parallel. Luckily, I don’t need to change our algorithm at all. The underlying JavaScript event loop will make it seem like the code is running in parallel, which is good enough for this article!

## Async/Await in Serial

In order to understand this *parallel* algorithm, I’ll first use async and await to build a *serial* algorithm. If you write this code in an IDE, you’ll likely get a notification saying that using await in a loop is a missed optimization opportunity *—* and your IDE would be correct.

```js {linenos=inline}
(async () => {
  const urls = [
    "https://example.com/posts/1/",
    "https://example.com/posts/1/tags/",
  ];

  const data = [];
  for (url of urls) {
    await fetch(url)
      .then((response) => response.json())
      .then((jsonResponse) => data.push(jsonResponse));
  }

  console.log(data);
})();
```

One reason that you might implement an algorithm like this is if you need to get the data from two different URLs, then blend that data together to create your final object. In the code above, you can imagine that we are gathering some data about a post, then grabbing the data about the post's tags, and finally merging that data into the object you’d actually use later on.

While this code will work, you might notice that we await on each fetch. You'll see something like:

* Start to fetch post one

* Wait for fetch post one to complete

* Get post one response

* Start fetch post one tags

* Wait for post one tags to complete

* Get post one tags response

The problem is we’re waiting serially for each network request to complete before starting the next request. There’s no need for this: Computers are perfectly capable of executing more than one network request at the same time.

So how can we make this algorithm better?

## Async/Await in Parallel

The easiest way to make this algorithm faster is to remove the await keyword before the fetch command. This will tell JavaScript to start the execution of all the requests in parallel. But in order to pause execution and wait for all of the promises to return, we need to await on something. We'll use Promise.all to do just that.

When we use await Promise.all, JavaScript will wait for the entire array of promises passed to Promise.all to resolve. Only then will it return all the results at the same time. A rewrite looks like this:

```js {linenos=inline}
(async () => {
    const urls = [
        "https://example.com/posts/1/",
        "https://example.com/posts/1/tags/",
    ];

    const promises = urls.map((url) =>
        fetch(url).then((response) => response.json())
    );

    const data = await Promise.all(promises);

    console.log(data);
})();
```

This code will map each URL into a promise and then await for all of those promises to complete. Now when we pass the await Promise.all portion of the code, we can be sure that both fetch requests have resolved and the responses are in the data array in the correct position. So data[0] will be our post data and data[1] will be our tags data.

## An Example

Now that we have all the necessary building blocks to implement our pre-fetched image gallery, let’s build it.

Below is a screenshot of the app I built for this article, and here is the link to the documentation about the [Harvard Art Museum API docs](https://github.com/harvardartmuseums/api-docs) [2]. You’ll need to apply for your own API key if you’d like to follow along. The process seemed pretty automatic to me since you just fill out a Google Form and then receive your API key in your email instantly.

<figure>

![Final Project](/images/posts/running-concurrent-requests-with-async-await-and-promise-all/01-harvard-gallery.png)

<figcaption align="center">Final Project</figcaption>

</figure>

It doesn’t look like much, but as you navigate through the gallery, it pre-fetches the next pages of data automatically. That way, the user viewing the gallery shouldn’t see any loading time for the actual data. The images are only loaded when they are displayed on the page. And while those do load after the fact, the actual data for the page is loaded instantly since it is cached in the component. Finally, as a challenge to myself, I’m using Salesforce’s Lightning Web Components for this project *— *a completely new technology to me. Let’s get into building the component.

Here are some of the resources that I used while learning about Lightning Web Components. If you’d like to follow along, then you’ll at least need to set up your local dev environment and create a “hello world” Lightning Web Component.

[Setup A Local Development Environment](https://trailhead.salesforce.com/content/learn/projects/quick-start-lightning-web-components/set-up-salesforce-dx) [3]

[Create a Hello World Lightning Web Component](https://trailhead.salesforce.com/content/learn/projects/quick-start-lightning-web-components/create-a-hello-world-lightning-web-component) [4]

[LWC Sample Gallery](https://trailhead.salesforce.com/sample-gallery) [5]

[LWC Component Reference](https://developer.salesforce.com/docs/component-library/overview/components) [6]

Alright, now that your environment is set up and you’ve created your first LWC, let’s get started. By the way, all the code for this article can be found at [my GitHub repo](https://github.com/bloveless/AsyncAwaitPromiseAllLWC) [7].

A quick aside: Lightning Web Components are a little more limited than components you might be used to if you are coming from a React background. For example, you can’t use JavaScript expressions in component properties, i.e. the image src, in the following example:

```xml {linenos=inline}
<template for:each={records} for:item="record">
    <img src={record.images[0].baseimageurl}>
</template>
```

The reason for that is when you force all of your code to happen in the JavaScript files rather than in the HTML template files, your code becomes much easier to test. So let’s chalk this up to "it's better for testing" and move on with our lives.

In order to create this gallery, we'll need to build two components. The first component is for displaying each gallery image, and the second component is for pre-fetching and pagination.

The first component is the simpler of the two. In VSCode, execute the command SFDX: Create Lightning Web Component and name the component harvardArtMuseumGalleryItem. This will create three files for us: an HTML, JavaScript, and XML file. This component will not need any changes to the XML file since the item itself isn't visible in any Salesforce admin pages.

Next, change the contents of the HTML file to the following:

```xml {linenos=inline}
# force-app/main/default/lwc/harvardArtMuseumGalleryItem/harvardArtMuseumGalleryItem.html

<template>
    <div class="gallery-item" style={backgroundStyle}></div>
    {title}
</template>
```

Note that in this HTML file, the style property is set to {backgroundStyle} which is a function in our JavaScript file, so let's work on that one.

Change the contents of the JS file to the following:

```js {linenos=inline}
// force-app/main/default/lwc/harvardArtMuseumGalleryItem/harvardArtMuseumGalleryItem.js

import { LightningElement, api } from 'lwc';

export default class HarvardArtMuseumGalleryItem extends LightningElement {
    @api
    record;

    get image() {
        if (this.record.images && this.record.images.length > 0) {
            return this.record.images[0].baseimageurl;
        }

        return "";
    }

    get title() {
        return this.record.title;
    }

    get backgroundStyle() {
        return `background-image:url('${this.image}');`
    }
}
```

There are a few things to notice here. First, the record property is decorated with @api which allows us to assign to this property from other components. Keep an eye out for this record property on the main gallery component. Also, since we can't have JavaScript expressions in our HTML files, I've also brought the background image inline CSS into the JavaScript file. This allows me to use string interpolation with the image. The image function is nothing special as it is *—* just an easy way for me to get the first image URL from the record that we received from the Harvard Art Gallery API.

Our final step of this component is to add a CSS file that wasn’t created for us automatically. So create harvardArtMuseumGalleryItem.css in the harvardArtMuseumGalleryItem directory. You don't need to tell the application to use this file as it is included automatically just by its existence.

Change the contents of your newly created CSS file to the following:

```css {linenos=inline}
/* force-app/main/default/lwc/harvardArtMuseumGalleryItem/harvardArtMuseumGalleryItem.css */

.gallery-item {
    height: 150px;
    width: 100%;
    background-size: cover;
}
```

Now that our busy work is out of the way, we can get to the actual gallery.

Run `SFDX: Create Lightning Web Component` in VSCode again and name the component harvardArtMuseumGallery. This will, once again, generate our HTML, JavaScript, and XML files. We need to pay close attention to the XML file this time. The XML file is what tells Salesforce where our component is allowed to be located as well as how we will store our API key in the component.

```xml {linenos=inline}
<!-- force-app/main/default/lwc/harvardArtMuseumGallery/harvardArtMuseumGallery.js-meta.xml -->

<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="<http://soap.sforce.com/2006/04/metadata>">
    <apiVersion>51.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__HomePage</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__HomePage">
            <property name="harvardApiKey" type="String" default=""></property>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

There are three key things to pay attention to in this XML file. The first is isExposed which will allow our component to be found in the Salesforce admin. The second is the target which says which areas of the Salesforce site our component can be used. This one says that we are allowing our component to be displayed on HomePage type pages. Finally, the targetConfigs section will display a text box when adding the component. There, we can paste our API key (as seen in the following screenshot). You can find more information about this XML file [here](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_lightningcomponentbundle.htm) [8].

<figure>

![Salesforce Page Builder](/images/posts/running-concurrent-requests-with-async-await-and-promise-all/02-salesforce-page-builder.png)

<figcaption align="center">Salesforce Page Builder</figcaption>

</figure>

Next, let’s take care of the HTML and CSS files.

```html {linenos=inline}
<!-- force-app/main/default/lwc/harvardArtMuseumGallery/harvardArtMuseumGallery.html -->

<template>
    <lightning-card title="HelloWorld" icon-name="custom:custom14">
        <div class="slds-m-around_medium">
          <h1>Harvard Gallery</h1>
          <div class="gallery-container">
            <template for:each={records} for:item="record">
              <div key={record.index} class="row">
                <template for:each={record.value} for:item="item">
                  <c-harvard-art-museum-gallery-item if:true={item} key={item.id} record={item}></c-harvard-art-museum-gallery-item>
                </template>
              </div>
            </template>
          </div>
          <div class="pagination-container">
            <button type="button" onclick={previousPage}>&lt;</button>
            <span class="current-page">
              {currentPage}
            </span>
            <button type="button" onclick={nextPage}>&gt;</button>
          </div>
        </div>
      </lightning-card>
</template>
```

Most of this is standard HTML with some custom components. The line I want you to pay attention to most is the <c-harvard-art-museum-gallery-item> tag and its record property. You’ll remember that this is the property we decorated with @api in the gallery item JavaScript file. The @api decoration allows us to pass in the record through this property.

Next, onto the CSS file:

```css {linenos=inline}
/* force-app/main/default/lwc/harvardArtMuseumGallery/harvardArtMuseumGallery.css */

h1 {
  font-size: 2em;
  font-weight: bolder;
  margin-bottom: .5em;
}

.gallery-container .row {
  display: flex;
}

c-harvard-art-museum-gallery-item {
  margin: 1em;
  flex-grow: 1;
  width: calc(25% - 2em);
}

.pagination-container {
  text-align: center;
}

.pagination-container .current-page {
  display: inline-block;
  margin: 0 .5em;
}
```

I’ve saved the most interesting for last! The JavaScript file includes our pre-fetching logic and page-rolling algorithm.

```js {linenos=inline}
// force-app/main/default/lwc/harvardArtMuseumGallery/harvardArtMuseumGallery.js

import { LightningElement, api } from "lwc";

const BASE_URL =
  "https://api.harvardartmuseums.org/object?apikey=$1&size=8&hasimage=1&page=$2";

export default class HarvardArtMuseumGallery extends LightningElement {
  @api harvardApiKey;

  error;
  records;
  currentPage = 1;
  pagesCache = [];

  chunkArray(array, size) {
    let result = [];
    for (let value of array) {
      let lastArray = result[result.length - 1];
      if (!lastArray || lastArray.length === size) {
        result.push([value]);
      } else {
        lastArray.push(value);
      }
    }

    return result.map((item, index) => ({ value: item, index: index }));
  }

  nextPage() {
    this.currentPage++;
    this.changePage(this.currentPage);
  }

  previousPage() {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.changePage(this.currentPage);
    }
  }

  connectedCallback() {
    this.changePage(1);
  }

  async changePage(page) {
    let lowerBound = ((page - 3) < 0) ? 0 : page - 3;
    const upperBound = page + 3;

    // Cache the extra pages
    const promises = [];
    for (let i = lowerBound; i <= upperBound; i++) {
      promises.push(this.getRecords(i));
    }

    Promise.all(promises).then(() => console.log('finished caching pages'));

    // Now this.pages has all the data for the current page and the next/previous pages
    // The idea is that we will start the previous promises in order to prefrech the pages
    // and here we will wait for the current page to either be delivered from the cache or
    // the api call
    this.records = await this.getRecords(page);
  }

  async getRecords(page) {
    if (page in this.pagesCache) {
      return Promise.resolve(this.pagesCache[page]);
    }

    const url = BASE_URL.replace("$1", this.harvardApiKey).replace("$2", page);
    return fetch(url)
      .then((response) => {
        if (!response.ok) {
          this.error = response;
        }

        return response.json();
      })
      .then((responseJson) => {
        this.pagesCache[page] = this.chunkArray(responseJson.records, 4);
        return this.pagesCache[page];
      })
      .catch((errorResponse) => {
        this.error = errorResponse;
      });
  }
}
```

Notice that we are decorating the harvardApiKey with @api. This is how the targetConfig property from our XML file will be injected into our component. Most of the code in this file facilitates changing pages and chunking the response so that we get rows of four gallery items. Pay attention to changePage as well as getRecords: this is where the magic happens. First, notice that changePage calculates a range of pages from whatever the current requested page is. If the current requested page is five, then we will cache all pages from two until page eight. We then loop over the pages and create a promise for each page.

Originally, I was thinking that we’d need to await on the Promise.all in order to avoid loading a page twice. But then I realized it is a low cost to pay in order to not wait for all of the pages to be returned from the API. So the current algorithm is as follows:

 1. User requests page five.

 2. Bounds are calculated as page two through page eight, and promises are created for those requests.

 3. Since we aren’t waiting for the promises to return, we will again request page five and make an extra API request (but this only happens for pages that aren’t in the cache).

 4. So let's say that the user progresses to page six.

 5. Bounds are calculated as pages three through nine, and promises are created for those requests.

 6. Since we already have pages two through eight in the cache, and since we didn’t await on those promises, page six will immediately load from the cache while the promise for page nine is being fulfilled (since it is the only page missing from the cache).

## Conclusion

And there you have it! We’ve explored concurrency and parallelism. We learned how to build an async/await flow in serial (which you should never do). We then upgraded our serial flow to be in parallel and learned how to wait for all the promises to resolve before continuing. Finally, we’ve built a Lightning Web Component for the Harvard Art Museum using async/await and Promise.all. (Although in this case, we didn't need the Promise.all since the algorithm works better if we don't wait for all the promises to resolve before continuing on.)

Thanks for reading and feel free to leave any comments and questions below.

Citations:

[1] [https://stackoverflow.com/questions/1050222/what-is-the-difference-between-concurrency-and-parallelism](https://stackoverflow.com/questions/1050222/what-is-the-difference-between-concurrency-and-parallelism)

[2] [https://github.com/harvardartmuseums/api-docs](https://github.com/harvardartmuseums/api-docs)

[3] [https://trailhead.salesforce.com/content/learn/projects/quick-start-lightning-web-components/set-up-salesforce-dx](https://trailhead.salesforce.com/content/learn/projects/quick-start-lightning-web-components/set-up-salesforce-dx)

[4] [https://trailhead.salesforce.com/content/learn/projects/quick-start-lightning-web-components/create-a-hello-world-lightning-web-component](https://trailhead.salesforce.com/content/learn/projects/quick-start-lightning-web-components/create-a-hello-world-lightning-web-component)

[5] [https://trailhead.salesforce.com/sample-gallery](https://trailhead.salesforce.com/sample-gallery)

[6] [https://developer.salesforce.com/docs/component-library/overview/components](https://developer.salesforce.com/docs/component-library/overview/components)

[7] [https://github.com/bloveless/AsyncAwaitPromiseAllLWC](https://github.com/bloveless/AsyncAwaitPromiseAllLWC)

[8] [https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_lightningcomponentbundle.htm](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_lightningcomponentbundle.htm)

## Published To
- [https://brennonloveless.medium.com/running-concurrent-requests-with-async-await-and-promise-all-daaca1b5da4d](https://brennonloveless.medium.com/running-concurrent-requests-with-async-await-and-promise-all-daaca1b5da4d)
- [https://dev.to/bloveless/running-concurrent-requests-with-async-await-and-promise-all-4gb1](https://dev.to/bloveless/running-concurrent-requests-with-async-await-and-promise-all-4gb1)
- [https://dzone.com/articles/running-concurrent-requests-with-asyncawait-and-pr](https://dzone.com/articles/running-concurrent-requests-with-asyncawait-and-pr)
- [https://hackernoon.com/tips-for-a-successful-concurrent-requests-with-asyncawait-and-promiseall-rk1l34f4](https://hackernoon.com/tips-for-a-successful-concurrent-requests-with-asyncawait-and-promiseall-rk1l34f4)
