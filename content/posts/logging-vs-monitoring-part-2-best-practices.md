---
title: "Logging Vs Monitoring Part 2: Best Practices"
date: 2021-02-02T16:00:00-07:00
draft: false
---

![Photo by [Denis Agati](https://unsplash.com/@denisagati?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/logging?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)](https://cdn-images-1.medium.com/max/9216/1*uWiPGX3ozxZzcYtiMl4hTw.jpeg)

## Best Practices for Logging

In [part one](https://brennonloveless.medium.com/logging-v-monitoring-5f234d4edbd7) I discussed why monitoring matters and some ways to implement that. Now let’s talk about some best practices we can implement to make monitoring easier. Let’s start with some best practices for logging — formatting, context, and level.

First, be sure you [**“log a lot and then log some more.**”](https://www.loomsystems.com/blog/single-post/2017/01/26/9-logging-best-practices-based-on-hands-on-experience) Log everything you might need in both the happy path and error path since you’ll only be armed with these logs when another error occurs in the future.

Until recently, I didn’t think I needed as many logs in the happy path. Meanwhile, my error path is full of helpful logging messages. Here is one example that just happened to me this week. I had some code that would read messages from a Kafka topic, validate them, and then pass them off to the DB to be persisted. Well, I forgot to actually push the message into the validated-messages array, which resulted in it always being empty. My point here is that everything was part of the happy path, so there weren’t any error logs for me to check. It took me a full day of adding logging and enabling debugging in production to find my mistake (that I forgot to push to the array). If I had messages like “Validating 1000 messages” and “Found 0 valid messages to be persisted,” it would have been immediately obvious that none of my messages were making it through. I could have solved it in an hour if I had “logged a lot and then logged some more.”

## Formatting

This is another logging tip that I had taken for granted until recently. The format of your log messages matters…. and it matters a lot.

People use [JSON-formatted logs](https://hackernoon.com/log-everything-as-json-hmq32ax) more and more these days and I’m starting to lean into it myself. After all, there are many benefits to using JSON as your logging format. That said, if you pick a different log format, stick to it across all your systems and services. One of the major JSON-format benefits is that it is super easy to have generic error messages, and then add additional data/context. For example. . .

    {
      "message": "Validating messages",
      "message_count": 1000
    }

or

    {
      "message": "Persisting messages",
      "message_count": 0
    }

These messages are harder for humans to read, but easy to group, filter, and read for machines. In the end, we want to push as much processing onto the machine as possible anyway!

Another tip about your actual log message: In many cases, you’ll be looking to find similar events that occurred. Maybe you found an error and you want to know how many times it occurred over the last seven days. If the error message is something like “System X failed because Z > Y” — where X, Y, and Z are all changing between each error message — then it will be difficult to classify those errors as the same.

To solve this, use a general message for the actual log message so you can search by the exact error wording. For example: “This system failed because there are more users than there are slots available.” Within the context of the log message, you can attach all the variables specific to this current failure.

This does require you to have an advanced-enough logging framework to attach context. But if you are using JSON for your log messages, then you could have the “message” field be the same string for every event; any other context would appear as additional fields in the JSON blob. That way, grouping messages is easy, and specific error data is still logged. Although, if you are using a JSON format, then I’d suggest that you have a “message” and a “display.” That way, you get the best of both worlds.

## Context

Rarely does a single log message paint the entire picture; including additional context with it will pay off. There is nothing more frustrating than when you get an alert saying “All your base are belong to us” and you have no idea what bases are missing or who “us” is referencing.

![](https://cdn-images-1.medium.com/max/2484/0*ifKkc7eVEApwn9lr.jpg)

Whenever you are writing a log message, imagine receiving it at 1am. Include all the relevant information your sleepy self would need to look into the issue as quickly as possible. You may also choose to log a transaction ID as part of your context. We’ll chat about those later.

## Level

Always use the correct level when writing your log messages. Ideally, your team will have different uses for the different log levels. Make sure you and your team are logging at the agreed-upon level when writing messages.

Some examples are INFO for general system state and probably happy-path code, ERROR for exceptions and non-happy-path code, WARN for things that might cause errors later or are approaching a limit, DEBUG for everything else. Obviously, these are just how I use some of the log levels. Try and lay out a log-level strategy with your team and stick to it.

Also, ensure that whatever logging aggregator you use allows for filtering by specific log levels or groups of log levels. When you view the state of your system, you probably don’t care about DEBUG level logs and want to just search for everything INFO and above, for example.

## Log Storage

In order for your logs to be accessible, you’ll need to store them somewhere. These days, it is unlikely that you’ll have a single log file that represents your entire system. Even if you have a monolithic application, you likely host it on more than one server. As such, you’ll need a system that can aggregate all these log files.

I prefer to store my logs in Elasticsearch, but if you are in another ecosystem like [Heroku](https://www.heroku.com), then you can use one of the provided [logging add-ons](https://elements.heroku.com/addons/categories/logging). There are even some free ones to get you started.

You may also prefer third-party logging services like Splunk or Datadog to ship your logs and monitor, analyze, and alert from there.

## Filtering

If you have logged all your messages at the correct levels and have used easily group-able log messages, then filtering becomes simple in any system configuration. Writing a query in Elasticsearch will be so much simpler when you’ve planned your log messages with this in mind.

## Transaction IDs

Let’s face it: Gone are the days when a single service handled the full request path. Only in rare cases or demo projects will your services be completely isolated from other services. Even something as simple as a front-end and a separate backend API can benefit from having transaction IDs. The idea is that you generate a transaction ID (which can be as simple as a UUID) as early as possible in your request path. That transaction ID gets passed through every request and stored with the data in whichever systems store it. This way, when there is an error four of five levels deep in your system, you can trace that request back to when the user first clicked the button. Using transaction IDs makes it easier to bridge the gap between systems. If you see an error in InfluxDB, then you can use the transaction ID to find any related messages in Elasticsearch.

## Other interesting metrics

Just recording log messages probably won’t provide the whole picture of your system. Here are a few more metrics that may interest you.

## Throughput

Keeping track of how quickly your system processes a batch of messages — or finishes some job — can easily illuminate subtler errors. You may also be able to detect errors or slowness in your downstream systems by using throughput monitoring. Maybe a database is acting slower than usual, or your database switched to an inefficient query plan. Well, throughput monitoring is a great way to detect these types of errors.

## Success vs Error

Of course, no system will ever have a 100% success rate. Maybe you expect your system to return a success error code at least 95% of the time. Logging your response codes will help you gauge if your expected success rates are dropping.

## Response Times

The last interesting metric I’ll discuss is response times. Especially when you’ve got a bunch of developers all pushing to a single code base, it is difficult to realize when you’ve impacted the response times of another endpoint. Capturing the overall response time of every request may give you the insight necessary to realize when response times increase. If you catch it early enough, it may not be hard to identify the commit that caused the issue.

## Conclusion

In this article, I’ve talked about the differences between logging and monitoring and why they are both necessary in a robust system. I’ve talked about some monitoring practices as well as some monitoring tools I like using. We experimented with a system and learned how to install and set up some monitoring tools for that system. Finally, I talked about some logging best practices that will make your life much easier and how better logging will make your monitoring tools much more useful.

If you have any questions, comments, or suggestions please leave them in the comments below and together we can all implement better monitors and build more reliable systems!

## Published To
- [https://brennonloveless.medium.com/logging-best-practices-82da864c6f22](https://brennonloveless.medium.com/logging-best-practices-82da864c6f22)
- [https://dev.to/bloveless/logging-best-practices-part-2-3916](https://dev.to/bloveless/logging-best-practices-part-2-3916)
- [https://dzone.com/articles/logging-best-practices-part-2](https://dzone.com/articles/logging-best-practices-part-2)
- [https://hackernoon.com/logging-vs-monitoring-best-practices-for-logging-part-2-rk2s33su](https://hackernoon.com/logging-vs-monitoring-best-practices-for-logging-part-2-rk2s33su?ref=hackernoon.com)
