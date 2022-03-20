---
title: "Test Driven Development With the Oclif Testing Library Part 2"
date: 2021-11-10T12:00:00-07:00
draft: false
---

In [Part One](/posts/test-driven-development-with-the-oclif-testing-library-part-1/) of this series on the oclif testing library, we used a test-driven development approach to building our time-tracker CLI. We talked about the [oclif framework](https://oclif.io/), which helps developers dispense with the setup and boilerplate so that they can get to writing the meat of their CLI applications. We also talked about [@oclif/test](https://github.com/oclif/test) and [@oclif/fancy-test](https://github.com/oclif/fancy-test), which take care of the repetitive setup and teardown so that developers can focus on writing their Mocha tests.

Our time-tracker application is a [multi-command CLI](https://oclif.io/docs/multi). We’ve already written tests and implemented our first command for adding a new project to our tracker. Next, we’re going to write tests and implement our “start timer” command.

Just as a reminder, the final application is posted on [GitHub](https://github.com/bloveless/oclif-time-tracker) as a reference in case you hit a roadblock.

## First Test for the Start Timer Command

Now that we can add a new project to our time tracker, we need to be able to start the timer for that project. The command usage would look like this:

```bash
time-tracker start-timer project-one
```

Since we’re taking a TDD approach, we’ll start by writing the test. For our happy path test, “project-one” already exists, and we can simply start the timer for it.

```js {linenos=inline}
// PATH: test/commands/start-timer.test.js

const {expect, test} = require('@oclif/test')
const StartTimerCommand = require('../../src/commands/start-timer')
const MemoryStorage = require('../../src/storage/memory')
const {generateDb} = require('../test-helpers')

const someDate = 1631943984467

describe('start timer', () => {
  test
  .stdout()
  .stub(StartTimerCommand, 'storage', new MemoryStorage(generateDb('project-one')))
  .stub(Date, 'now', () => someDate)
  .command(['start-timer', 'project-one'])
  .it('should start a timer for "project-one"', async ctx => {
    expect(await StartTimerCommand.storage.load()).to.eql({
      activeProject: 'project-one',
      projects: {
        'project-one': {
          activeEntry: 0,
          entries: [
            {
              startTime: new Date(someDate),
              endTime: null,
            },
          ],
        },
      },
    })
    expect(ctx.stdout).to.contain('Started a new time entry on "project-one"')
  })
})
```

There is a lot of similarity between this test and the first test of our “add project” command. One difference, however, is the additional stub() call. Since we will start the timer with new Date(Date.now()), our test code will preemptively stub out Date.now() to return someDate. Though we don’t care what the value of someDate is, what’s important is that it is fixed.

When we run our test, we get the following error:

```bash
Error: Cannot find module '../../src/commands/start-timer'
```

It’s time to write some implementation code!

## Beginning to Implement the Start Time Command

We need to create a file for our start-timer command. We duplicate the add-project.js file and rename it as start-timer.js. We clear out most of the run method, and we rename the command class to StartTimerCommand.

```js {linenos=inline}
const {Command, flags} = require('@oclif/command')
const FilesystemStorage = require('../storage/filesystem')

class StartTimerCommand extends Command {
  async run() {
    const {args} = this.parse(StartTimerCommand)
    const db = await StartTimerCommand.storage.load()

    await StartTimerCommand.storage.save(db)
  }
}

StartTimerCommand.storage = new FilesystemStorage()

StartTimerCommand.description = `Start a new timer for a project`

StartTimerCommand.flags = {
  name: flags.string({char: 'n', description: 'name to print'}),
}

module.exports = StartTimerCommand
```

Now, when we run the test again, we see that the db has not been updated as we had expected.

```
1) start timer
       should start a timer for "project-one":

      AssertionError: expected { Object (activeProject, projects) } to deeply equal { Object (activeProject, projects) }
      + expected - actual

       {
      -  "activeProject": [null]
      +  "activeProject": "project-one"
         "projects": {
           "project-one": {
      -      "activeEntry": [null]
      -      "entries": []
      +      "activeEntry": 0
      +      "entries": [
      +        {
      +          "endTime": [null]
      +          "startTime": [Date: 2021-09-18T05:46:24.467Z]
      +        }
      +      ]
           }
         }
       }

      at Context.<anonymous> (test/commands/start-timer.test.js:16:55)
      at async Object.run (node_modules/fancy-test/lib/base.js:44:29)
      at async Context.run (node_modules/fancy-test/lib/base.js:68:25)
```

While we’re at it, we also know that we should be logging something to tell the user what just happened. So let’s update the run method with code to do that.

```js {linenow=inline}
const {args} = this.parse(StartTimerCommand)
const db = await StartTimerCommand.storage.load()

if (db.projects && db.projects[args.projectName]) {
  db.activeProject = args.projectName
  // Set the active entry before we push so we can take advantage of the fact
  // that the current length is the index of the next insert
  db.projects[args.projectName].activeEntry = db.projects[args.projectName].entries.length
  db.projects[args.projectName].entries.push({startTime: new Date(Date.now()), endTime: null})
}

this.log(`Started a new time entry on "${args.projectName}"`)

await StartTimerCommand.storage.save(db)
```

Running the test again, we see that our tests are all passing!

```
add project
    ✓ should add a new project
    ✓ should return an error if the project already exists (59ms)

start timer
    ✓ should start a timer for "project-one"
```

## Sad Path: Starting a Timer on a Non-Existent Project

Next, we should notify the user if they attempt to start a timer on a project that doesn’t exist. Let’s start by writing a test for this.

```js {linenos=inline}
test
  .stdout()
  .stub(StartTimerCommand, 'storage', new MemoryStorage(generateDb('project-one')))
  .stub(Date, 'now', () => someDate)
  .command(['start-timer', 'project-does-not-exist'])
  .catch('Project "project-does-not-exist" does not exist')
  .it('should return an error if the user attempts to start a timer on a project that doesn\'t exist', async _ => {
    // Expect that the storage is unchanged
    expect(await StartTimerCommand.storage.load()).to.eql({
      activeProject: null,
      projects: {
        'project-one': {
          activeEntry: null,
          entries: [],
        },
      },
    })
  })
```

And, we are failing again.

```
1 failing

  1) start timer
        should return an error if the user attempts to start a timer on a project that doesn't exist:
      Error: expected error to be thrown
      at Object.run (node_modules/fancy-test/lib/catch.js:8:19)
      at Context.run (node_modules/fancy-test/lib/base.js:68:36)
```

Let’s write some code to fix that error. We add the following snippet of code to the beginning of the run method, right after we load the db from storage.

```js
if (!db.projects?.[args.projectName]) {
	this.error(`Project "${args.projectName}" does not exist`)
}
```

We run the tests again.

```
add project
    ✓ should add a new project (47ms)
    ✓ should return an error if the project already exists (75ms)

start timer
    ✓ should start a timer for "project-one"
    ✓ should return an error if the user attempts to start a timer on a project that doesn't exist
```

Nailed it! Of course, there is one more thing that this command should do. Let’s imagine that we’ve already started a timer on project-one and we want to quickly switch the timer to project-two. We'd expect that the running timer on project-one will stop and a new timer on project-two will begin.

## Stop One Timer, Start Another

We repeat our TDD red-green cycle by first writing a test to represent the missing functionality.

```js {linenos=inline}
test
  .stdout()
  .stub(StartTimerCommand, 'storage', new MemoryStorage({
    activeProject: 'project-one',
    projects: {
      'project-one': {
        activeEntry: 0,
        entries: [
          {
            startTime: new Date(someStartDate),
            endTime: null,
          },
        ],
      },
      'project-two': {
        activeEntry: null,
        entries: [],
      },
    },
  }))
  .stub(Date, 'now', () => someDate)
  .command(['start-timer', 'project-two'])
  .it('should end the running timer from another project before starting a timer on the requested one', async ctx => {
    // Expect that the storage is unchanged
    expect(await StartTimerCommand.storage.load()).to.eql({
      activeProject: 'project-two',
      projects: {
        'project-one': {
          activeEntry: null,
          entries: [
            {
              startTime: new Date(someStartDate),
              endTime: new Date(someDate),
            },
          ],
        },
        'project-two': {
          activeEntry: 0,
          entries: [
            {
              startTime: new Date(someDate),
              endTime: null,
            },
          ],
        },
      },
    })

    expect(ctx.stdout).to.contain('Started a new time entry on "project-two"')
  })
```

This test requires another timestamp, which we call someStartDate. We add that near the top of our start-timer.test.js file:

```js
...
const someStartDate = 1631936940178
const someDate = 1631943984467
```

This test is longer than the other tests, but that’s because we needed a very specific db initialized within MemoryStorage to represent this test case. You can see that, initially, we have an entry with a startTime and no endTime in project-one. In the assertion, you'll notice that the endTime in project-one is populated, and there is a new active entry in project-two with a startTime and no endTime.

When we run our test suite, we see the following error:

```
1) start timer
       should end the running timer from another project before starting a timer on the requested one:

      AssertionError: expected { Object (activeProject, projects) } to deeply equal { Object (activeProject, projects) }
      + expected - actual

       {
         "activeProject": "project-two"
         "projects": {
           "project-one": {
      -      "activeEntry": 0
      +      "activeEntry": [null]
             "entries": [
               {
      -          "endTime": [null]
      +          "endTime": [Date: 2021-09-18T05:46:24.467Z]
                 "startTime": [Date: 2021-09-18T03:49:00.178Z]
               }
             ]
           }

      at Context.<anonymous> (test/commands/start-timer.test.js:76:55)
      at async Object.run (node_modules/fancy-test/lib/base.js:44:29)
      at async Context.run (node_modules/fancy-test/lib/base.js:68:25)
```

This error tells us that our CLI correctly created a new entry in project-two, but it didn't first end the timer on project-one. Our application also didn't change the activeEntry from 0 to null in project-one as we expected.

Let’s fix up the code to solve this issue. Right after we check that the requested project exists, we can add this block of code which will end a running timer on another project and unset the activeEntry in that project, and it does that all before we create a new timer on the requested project.

```js {linenos=inline}
// Check to see if there is a timer running on another project and end it
if (db.activeProject && db.activeProject !== args.projectName) {
	db.projects[db.activeProject].entries[db.projects[db.activeProject].activeEntry].endTime = new Date(Date.now())
	db.projects[db.activeProject].activeEntry = null
}
```

And there we have it! All our tests are passing once again!

```
add project
    ✓ should add a new project (47ms)
    ✓ should return an error if the project already exists (72ms)

  start timer
    ✓ should start a timer for "project-one"
    ✓ should return an error if the user attempts to start a timer on a project that doesn't exist
    ✓ should end the running timer from another project before starting a timer on the requested one
```

## Conclusion

If you’ve been tracking with our CLI development over Part One and Part Two of this oclif testing series, you’ll see that we’ve covered the add-project and start-timer commands. We’ve been demonstrating how easy it is to use TDD to build these commands with oclif and @oclif/test.

Because the end-timer and list-projects commands are so similar to what we’ve already walked through, we’ll leave their development using TDD as an exercise for the reader. The [project repository](https://github.com/bloveless/oclif-time-tracker) has those commands implemented as well as the tests used to validate the implementation.

In summary, we laid out plans for using TDD to build a CLI application using the oclif framework. We spent some time getting to know the @oclif/test package and some of the helpers provided by that library. Specifically, we talked about:

* Using the command method for calling our command and passing it arguments

* Methods provided by @oclif/fancy-test for stubbing parts of our application, catching errors, mocking stdout and stderr, and asserting on those results

* Using TDD to build out a large portion of a CLI using a red-green cycle by writing tests first and then writing the minimal amount of code to get our tests to pass

Just like that… you’ve got another tool in your dev belt — this time, for writing and testing your own CLIs!

## Published To
- [https://brennonloveless.medium.com/test-driven-development-with-the-oclif-testing-library-part-two-13698e694d16](https://brennonloveless.medium.com/test-driven-development-with-the-oclif-testing-library-part-two-13698e694d16)
- [https://dev.to/bloveless/test-driven-development-with-the-oclif-testing-library-part-two-3aab](https://dev.to/bloveless/test-driven-development-with-the-oclif-testing-library-part-two-3aab)
- [https://dzone.com/articles/test-driven-development-with-the-oclif-testing-lib-1](https://dzone.com/articles/test-driven-development-with-the-oclif-testing-lib-1)
- [https://hackernoon.com/build-a-cli-app-with-oclif-and-nodejs-using-test-driven-development-part-2](https://hackernoon.com/build-a-cli-app-with-oclif-and-nodejs-using-test-driven-development-part-2)
