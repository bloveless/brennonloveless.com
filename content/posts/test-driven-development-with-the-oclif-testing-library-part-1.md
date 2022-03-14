---
title: "Test Driven Development With the Oclif Testing Library Part 1"
date: 2021-11-09T12:00:00-07:00
draft: false
---

![Photo by [Kevin Ku](https://unsplash.com/@ikukevk?utm_source=medium&utm_medium=referral) on [Unsplash](https://unsplash.com?utm_source=medium&utm_medium=referral)](https://cdn-images-1.medium.com/max/9184/0*FH9lms6AgPOldECi)

While writing a CLI tool can be a lot of fun, the initial setup and boilerplate — parsing arguments and flags, validation, subcommands — is generally the same for every CLI, and it’s a drag. That’s where the [oclif framework](https://oclif.io/) saves the day. The boilerplate for writing a single-command or multi-command CLI melts away, and you can quickly get into the code that you *actually* want to write.

But wait — there’s more! oclif also has a testing framework that lets you execute your CLI the same way a user would, capturing standard output and errors so that you can test expectations. In this article, I’ll show you how to write and test an oclif CLI application with ease.

## What Are We Going To Build?

We’re all tired of working on the typical TODO application. Instead, let’s build something different but simple. We’ll use a test-driven development (TDD) approach to build a time-tracking application. Our CLI will let us do the following:

* Add projects

* Start and end timers on those projects

* View the total spend on a project

* View the time spent on each entry for a given project

Here’s what a sample interaction with the time-tracker CLI looks like:

    ~ time-tracker add-project project-one
    Created new project "project-one"

    ~ time-tracker start-timer project-one
    Started a new time entry on "project-one"

    ~ time-tracker start-timer project-two
     >   Error: Project "project-two" does not exist

    ~ time-tracker add-project project-two
    Created new project "project-two"

    ~ time-tracker start-timer project-two
    Started a new time entry on "project-two"

    ~ time-tracker end-timer project-two
    Ended time entry for "project-two"

    ~ time-tracker list-projects
    project-one (0h 0m 13.20s)
    - 2021-09-20T13:13:09.192Z - 2021-09-20T13:13:22.394Z (0h 0m 13.20s)
    project-two (0h 0m 7.79s)
    - 2021-09-20T13:13:22.394Z - 2021-09-20T13:13:30.189Z (0h 0m 7.79s)

We’ll manage all of the data about added projects and active timers in a “database” (a simple JSON data file).

The source code for our time tracking application project can be found [here](https://github.com/bloveless/oclif-time-tracker).

Since we’re doing this the TDD way, let’s dive in… tests first!

## Our Time-Tracker: Features and Tests

As we describe our application’s features, we should be thinking about tests we can write to assert the expectations we have for those features. Here is a list of our application’s features:

### Create a new project

* **Happy path**: The new project is created, and its record is stored in the underlying database. The user receives a confirmation message.

* **Sad path**: If the project already exists, then an error message will appear to the user. The underlying database will be unaltered.

### Start a timer on a project

* **Happy path**: The requested project already exists, so we can start a new time entry, setting the startTime to the current date/time. The user will receive a notification when the timer begins.

* **Happy path**: If the timer is already running on another project, then that timer will stop and a new timer will begin on the requested project. The user will receive a notification when the timer begins.

* **Sad path**: If the project doesn’t exist, then an error message will appear to the user. The underlying database will be unaltered.

### End a timer on a project

* **Happy path**: A timer is active on the requested project, so we can end that timer and notify the user.

* **Sad path**: If the project doesn’t exist, then an error message will appear to the user. The underlying database will be unaltered.

* **Sad path**: If the project exists without an active timer, then the user will be notified. The underlying database will be unaltered.

### List project

* **Happy path**: All the projects, total times, entries, and entry times are displayed to the user.

### Database existence (for all commands)

* **Sad path**: If the time.json file doesn’t exist in the current directory, then an error message appears to the user.

For data storage — our “database” — we’ll store our time entries on disk as JSON, in a file called time.json. Below is an example of how this file may look:

 <iframe src="https://medium.com/media/bf7c88e56cc211efe7555e0ebb668d60" frameborder=0></iframe>

## Design Decisions

Finally, let’s cover some of the design decisions for our overall application.

First, we’ll store an activeProject at the top level of our JSON data. We can use this to quickly check which project is active. Second, we’ll store an activeEntry field in *each project*, which stores the index of the entry that is currently being worked on.

With these two pieces of information, we can navigate directly to the active project and its active entry in order to end the timer. We can also determine instantly if the project has any active entries or if there are any active projects.

## Project Setup

Now that we’ve laid all the groundwork, let’s create a new project and start digging in. Here’s the first command:

    npx oclif multi time-tracker

This command creates a new [multi-command oclif application](https://oclif.io/docs/multi). With a multi-command CLI, we can run commands like time-tracker add-project project-one and time-tracker start-timer project-one. In these examples, both add-project and start-timer are separate commands, each stored in its own source file in the project, but they all fall under the umbrella time-tracker CLI.

## A Word About Stubs

We want to take advantage of the test helpers provided by @oclif/test. For testing our particular application, we’ll need to write a simple stub. Here’s why:

Our application writes to a timer.json file on the filesystem. Imagine if we were running our tests in parallel and had ten tests that were all writing to the same file at the same time. That would get messy and produce unpredictable results.

A better approach would be to make each test write to its own file, test against those files, and clean up after ourselves. Better yet, each test could write to an object in memory instead of a file, and we can assert our expectations on that object.

The best practice when writing unit tests is to replace the driver with something else. In our case, we will stub out the default FilesystemStorage driver with a MemoryStorage driver.

[@oclif/test](https://github.com/oclif/test) is a simple wrapper around [@oclif/fancy-test](https://github.com/oclif/fancy-test) that adds some functionality around testing CLI commands. We’re going to use the [stub functionality](https://github.com/oclif/fancy-test#stub) in @oclif/fancy-test to replace the storage driver in our command for testing.

## Our First Command: Add Project

Now, let’s talk about the “add project” command and the important parts related to mocking out the filesystem. Every new oclif project starts with a hello.js file in src/commands. We’ve renamed it to add-project.js file and fill it in with the bare minimum.

 <iframe src="https://medium.com/media/c49ef26cd11fa41ae124a4c68b38ef8a" frameborder=0></iframe>

## Swappable Storage for Tests

Notice how I statically assign a FilesystemStorage instance to AddProjectCommand.storage. This allows me—in my tests—to swap out the filesystem storage with an in-memory storage implementation. Let’s look at the FilesystemStorage and MemoryStorage classes below.

 <iframe src="https://medium.com/media/7c8818561ce2cfbd96153c0365cd7bee" frameborder=0></iframe>

FilesystemStorage and MemoryStorage have the same interface, so we can swap one out for the other in our tests.

## The First Test for the Add Project Command

In test/commands, we renamed hello.test.js to add-project.test.js, and we’ve written our first test:

 <iframe src="https://medium.com/media/248cee8a70f2fb4fb4adca5f9162a847" frameborder=0></iframe>

The magic happens in the stub call. We swap out the FilesystemStorage with MemoryStorage (with an empty object for initial data). Then, we assert expectations on the storage contents.

## Unpacking the test Command From [@oclif/Test](http://twitter.com/oclif/Test)

Before we implement our command, let’s make sure we understand our test file. Our describe block calls test, which is the entry point to @oclif/fancy-test (re-exported from @oclif/test).

Next, the .stdout() method captures the output from the command, letting you assert expectations on it by using ctx.stdout. There is also a .stderr() method, but we'll see later that there is another more preferred method for handling errors in @oclif/fancy-test.

For most applications, you wouldn’t normally make assertions against what’s being written to standard out. However, in the case of a CLI, this is one of your major interfaces with the user, so testing against standard out makes sense.

Keep in mind that there is a major gotcha here! If you use console.log to debug while you are developing, then .stdout() **will capture that output as well.** Unless you are asserting against ctx.stdout, you'll probably never see that output.

    .stub(AddProjectCommand, 'storage', new MemoryStorage({}))

We’ve talked about the .stub method a bit already, but what we’re doing here is replacing the static property on our command with MemoryStorage instead of the default FilesystemStorage.

    .command(['add-project', 'project-one'])

The method .command is where things get really cool with @oclif/test. This line calls your CLI just like you would from the command line. You can pass in flags and their values or a list of arguments like I'm doing here. @oclif/test will do the work of calling your command the exact same way as it would be called by an end user at the command line.

    .it('test description', () => [...])

You might be familiar with it blocks. This is where you normally do all the work to set up your test and run assertions against the results. Things are pretty similar here, but you've probably already done the hard work of setting up your test with the other helpers from @oclif/test and @oclif/fancy-test, and the it block needs only to assert against the output of the command.

Finally, now that we understand a bit more about what the test does, we can run our tests with npm test. Since we haven’t written any implementation code, we would expect our test to fail.

    1) add project
           should add a new project:
         Error: Unexpected argument: project-one
    See more help with --help
          at validateArgs (node_modules/@oclif/parser/lib/validate.js:10:19)
          at Object.validate (node_modules/@oclif/parser/lib/validate.js:55:5)
          at Object.parse (node_modules/@oclif/parser/lib/index.js:28:7)
          at AddProjectCommand.parse (node_modules/@oclif/command/lib/command.js:86:41)
          at AddProjectCommand.run (src/commands/add-project.js:1:1576)
          at AddProjectCommand._run (node_modules/@oclif/command/lib/command.js:43:31)

Perfect! A failed test, just as we expected. Let’s write the code to get to green.

## Getting to Green: Implementing Our Command

Now, we just have to follow the errors to write our command. First, we need to update the AddProjectCommand class to be aware of the arguments we want to pass in. In this case, we are only passing in a project name. Let’s make that change with the following:

    class AddProjectCommand extends Command {
      ...
    }

    AddProjectCommand.storage = new FilesystemStorage()

    AddProjectCommand.description = 'Add a new project to the time tracking database'

    // This is the update
    AddProjectCommand.args = [
      {name: 'projectName', required: true},
    ]

We need to tell oclif about our command’s expected arguments and their properties. In our case, there is only one argument, projectName, and it is required. You can learn more about oclif arguments [here](https://oclif.io/docs/args), and oclif flags [here](https://oclif.io/docs/flags).

Now, we run the test again, as shown below:

    1) add project
           should add a new project:

    AssertionError: expected {} to deeply equal { Object (activeProject, projects) }
          + expected - actual

    -{}
          +{
          +  "activeProject": [null]
          +  "projects": {
          +    "project-one": {
          +      "activeEntry": [null]
          +      "entries": []
          +    }
          +  }
          +}

    at Context.<anonymous> (test/commands/add-project.test.js:11:55)
          at async Object.run (node_modules/fancy-test/lib/base.js:44:29)
          at async Context.run (node_modules/fancy-test/lib/base.js:68:25)

Wonderful! We are now seeing that, while we had expected “project-one” to be created, there was no change made to the underlying data structure.

Let’s update the command with the minimum amount of code necessary to make this test pass. For brevity, we’ll only display the run() method in src/commands/add-project.js.

 <iframe src="https://medium.com/media/ba27cd29f73bd5aa18ded28f9b33d946" frameborder=0></iframe>

By default, if no file exists, then we will receive an empty object when loading from storage. This code creates any default properties and their values if they didn’t exist (for example, activeProject and projects), then it creates a new project with the default structure—an empty entries array and activeEntry set to null.

Running the test again, we see the next error:

    1) add project
           should add a new project:
         AssertionError: expected '' to include 'Created new project "project-one"'
          at Context.<anonymous> (test/commands/add-project.test.js:20:27)
          at async Object.run (node_modules/fancy-test/lib/base.js:44:29)
          at async Context.run (node_modules/fancy-test/lib/base.js:68:25)

This is where the .stdout() function comes into play. We expected our CLI to tell the user that we created their new project, but it didn't say anything. This one is easy to fix. We can add the following line right before we call storage.save().

    this.log(`Created new project "${args.projectName}"`)

Voila! Our first happy path test is passing. Now we’re cruising!

    add project
        ✓ should add a new project (43ms)

    1 passing (44ms)

## One More Test

We’ve got one more test for AddProjectCommand. We need to make sure that the user cannot add another project with the same name as the current project. For these tests, we’ll repeatedly need to generate a database for a single project. Let’s create a helper for this.

In test/test-helpers.js add the following:

 <iframe src="https://medium.com/media/2b0fae2bc549a5954b6445e0b48cefd9" frameborder=0></iframe>

Now, we can add the next test in add-project.test.js:

 <iframe src="https://medium.com/media/d2a5d5c051beb1dd812d3c0739bc7248" frameborder=0></iframe>

There is a new method in this test:

    .catch('Project "project-one" already exists')

I mentioned earlier that we don’t need to mock stderr to assert against it. That’s because we can use this catch method to assert against any errors that happened during the run. In this case, we are expecting that an error will occur and that the underlying storage is unchanged.

After running our test again, we see the following:

    1) add project
           should return an error if the project already exists:
         Error: expected error to be thrown
          at Object.run (node_modules/fancy-test/lib/catch.js:8:19)
          at Context.run (node_modules/fancy-test/lib/base.js:68:36)

Right after we load db from storage, we need to check and see if the project already exists and throw an error if it does.

    const db = await AddProjectCommand.storage.load()

    // New code
    if (db.projects?.[args.projectName]) {
        this.error(`Project "${args.projectName}" already exists`)
    }

Now, when we run our tests, they all pass! We’ve done it! We can now add as many projects as we’d like to track our time.

    add project
        ✓ should add a new project (46ms)
        ✓ should return an error if the project already exists (76ms)

## Conclusion (for now)

In this article — part one of our two-part series on the oclif testing library — we’ve talked about oclif, its testing framework, why stubs are useful, and how to use them. Then, we began writing tests and implementation for our time-tracker CLI.

This is a great start. In the next part of our series, we’ll continue building out our CLI with more commands while covering important testing concepts like data store testing and initialization.

## Published To
- [https://betterprogramming.pub/build-a-time-tracking-cli-application-using-a-test-driven-development-9d238f3c306c](https://betterprogramming.pub/build-a-time-tracking-cli-application-using-a-test-driven-development-9d238f3c306c)
- [https://dev.to/salesforcedevs/test-driven-development-with-the-oclif-testing-library-part-one-25h9](https://dev.to/salesforcedevs/test-driven-development-with-the-oclif-testing-library-part-one-25h9)
- [https://dzone.com/articles/test-driven-development-with-the-oclif-testing-lib](https://dzone.com/articles/test-driven-development-with-the-oclif-testing-lib)
- [https://hackernoon.com/build-a-cli-app-with-oclif-and-nodejs-using-test-driven-development](https://hackernoon.com/build-a-cli-app-with-oclif-and-nodejs-using-test-driven-development)
