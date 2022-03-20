---
title: "How I Backup and Restore Data in my Kubernetes Persistent Volumes"
date: 2020-04-20T12:00:00-07:00
draft: false
---

<figure>

![Photo by Jason Pofahl on Unsplash(https://unsplash.com?utm_source=medium&utm_medium=referral)](/images/posts/how-i-backup-and-restore-data-in-my-kubernetes-persistent-volumes/01-bank-vault.jpg)

<figcaption align="center">Photo by <a href="https://unsplash.com/@jasonpofahlphotography?utm_source=medium&utm_medium=referral">Jason Pofahl</a> on <a href="https://unsplash.com?utm_source=medium&utm_medium=referral">Unsplash</a></figcaption>

</figure>

## Let me tell you a story

I have been playing with Kubernetes for a while now. I run a three-node cluster as VM's on a server in a basement somewhere. I’ve only been hosting my father’s website and various other experiments on this cluster, none of this receives very much traffic and (don’t tell my dad this) but I take his website down all the time by experimenting with the server, Kubernetes, and his website. So far this has just been for fun.

Then my world was about to change. My sister was starting a new company ([http://medegreed.com](http://medegreed.com/)) and needed a web presence! Hurrah! I had just the thing to help her out and save her some money. I threw her website up in a new container and handed the reins over to her and her business partner to start populating the website. About a week later and a drive failed in my RAID array. No worries I said! I ordered a new drive and replaced the wrong drive in the RAID array… my luck. I was able to recover just about everything except my MySQL server and persistent volumes attached to my containers which equates to restoring just about nothing.

Imagine the phone call where I had to call my sister and tell her and her business partner that I accidentally blew away all the work that they had done this week. Their first question was the obvious one… can we just restore it from the backup? Once again I had to let them down saying that I didn’t have any backups. I was saddened to have to suggest to them that they would probably be safer with GoDaddy until I figured something out… we’ll I’ve figured it out and they are happy on GoDaddy. That is how I lost what should have been the easiest client I would ever have.

The rest of this article is how I prevented this from ever happening to me again.

*I’m actually not going to talk about how I backup MySQL to S3 as that is just a simple script that runs MySQL dump and then uploads that data and syncs it to S3. If anyone is interested in that script or process, please leave a comment and my next article will be about that.*

## The requirements

First and most obvious I needed backups. Second and almost the most important is the solution needed to be easy to restore since a backup that is difficult to restore is as bad as no backup at all. Okay, that was me being a little dramatic but I think we can all agree that backups that are difficult to restore from aren’t fun in an emergency. Lastly, in order to conserve space and cost in AWS, I wanted rolling backups for hourly, daily, weekly, and monthly backups.

The four types of rolling backups are overkill for my use case. Imagine a corporation with many people uploading and deleting assets from their public website. It doesn’t seem like a stretch to imagine that someone could have deleted something on accident but not realized it until they are notified of a broken page a week or so later. The rolling backups of each type allow a greater chance that recovery is possible. Although this type of recovery would be manual, it is still possible to go back two months and recover a few deleted files.

## The solution

First I attempted to find a solution that already existed. I really liked my set of requirements so I wanted to find something that matched exactly. Not to mention that I really didn’t want to find something so I’d have the opportunity to build something! I found a few that met all but the rolling backup requirements and others that had difficult/manual restore processes. Essentially I found my excuse to build something!

I came up with is a docker image ([https://hub.docker.com/r/bloveless/s3-backup-restore](https://hub.docker.com/r/bloveless/s3-backup-restore)) that can run either a one-off backup (mostly for development), can run a backup cron (to generate the hourly, daily, weekly, and monthly backups), or can run a restore command to download and extract the latest backup from S3. The way it works is by running two containers in addition to the container you want to backup. The first container is an initContainer and it runs a restore command every time the pod starts up. The restore command first checks the data directory to see if there are any files and if not it does an automatic restore to a volume shared with the main container. The second container runs as a sidecar container to the main container. They both share a persistent volume so the backup container will periodically backup the contents of the shared volume by compressing the data into a tar.gz and uploading it to S3. Bam! Automatic backups and restores.

I’d like to spend a moment talking about the restore process since I think it is pretty cool. Take my father's website for example. It uses a persistent volume to store any uploads from the CMS. Now when I’m performing one of my experiments and switching out the container storage platform all I have to do is delete his entire website; content and everything. Now I can uninstall and reinstall a new storage provider and when I re-add his website the initContainer will notice that his data directory is empty and will download the latest backup from S3 and restore his content. Pretty slick if you ask me!

Let's talk about the app itself. Below you can see the Kubernetes config for the initContainer for restoring as well as the sidecar container for backing up. I’ve really bought into the idea that apps should be configurable by the environment in which they live. So my container takes a very simple argument either backup, restore, or cron and the rest of the features are enabled and configured through environment variables. If you check out the README.md on the docker hub link above you’ll see that there are quite a few different ways to configure the app through environment variables.

Below are some example environment configs for the initContainer and sidecar container.

```yaml
  initContainers:
    - name: s3-restore
      image: bloveless/s3-backup-restore:1.0.0
      volumeMounts:
        - name: public-files
          mountPath: /data
      args: ["restore"]
      tty: true
      env:
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: backup-keys
              key: aws_access_key_id
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: backup-keys
              key: aws_secret_access_key
        - name: AWS_REGION
          value: "us-west-2"
        - name: S3_BUCKET
          value: "my-backup-bucket"
        - name: S3_PATH
          value: "my-backup-path"
        - name: CHOWN_ENABLE
          value: "true"
        - name: CHOWN_UID
          value: "1000"
        - name: CHOWN_GID
          value: "1000"

  containers:
    - name: s3-backup
      image: bloveless/s3-backup-restore:1.0.0
      volumeMounts:
        - name: public-files
          mountPath: /data
      command: ["cron"]
      env:
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: backup-keys
              key: aws_access_key
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: backup-keys
              key: aws_secret_key
        - name: AWS_REGION
          value: "us-west-2"
        - name: S3_BUCKET
          value: "my-backup-bucket"
        - name: S3_PATH
          value: "my-backup-path"
        - name: CHOWN_ENABLE
          value: "true"
        - name: CHOWN_UID
          value: "1000"
        - name: CHOWN_GID
          value: "1000"
```

The app also supports forcing a restore in case you don’t care what is in the directory and you just want to replace data in the directory. You can specify the file you want to restore from as well, in case you need to skip a corrupt backup or two. Finally, the app can also reset the user and group after a restore. All of those features are configurable through environment variables.

I initially wrote the image in bash as thought it would be the simplest and smallest image. After I had all the dependencies installed the compressed image was around 57Mb using an alpine base image and this felt a little too large for me. I thought I could do a little better by using a compiled language and a less “alpiney” image. So I used the debian-slim image and rewrote the app in Go. This got it down to 35Mb and using a Debian image which just feels a little better for me. Maybe later I’ll write about my struggles with alpine and musl libc, but that's for another article.

Another benefit of using a programming language rather than bash is that I have the ability to write unit tests a lot easier! Um… I didn’t write any unit tests yet but have plans to do so. So don’t go looking for the tests and then scold me for not writing any!

## Where to go next

Part of why I wanted to rewrite this image was to add compression since my AWS S3 fees were getting into the $10 range just for backups and I felt like this was a little high. So to optimize that cost a little more I’m going to look into using S3 Glacier to put some of the older backups into cold storage automatically. That’s not a change that will need to happen in the code, but a setting in S3 to automatically store older backups in Glacier which is significantly cheaper than S3 alone.

<figure>

![Dependency struct when doing a backup](/images/posts/how-i-backup-and-restore-data-in-my-kubernetes-persistent-volumes/02-depdendency-struct.png)

<figcaption align="center">Dependency struct when doing a backup</figcaption>

</figure>

I mentioned unit tests above which means that I should add unit tests to this. I’m currently using a pattern that is common in Go where you have dependency structs which contain your, you guessed it, dependencies. This makes it really easy to mock those dependencies for unit testing especially when you put interfaces in there. Look at the S3Service interface in the code as an example. What I found out is that the s3iface.S3API interface has over 300 methods in it. It seems like implementing that interface for a mock is not going to be an easy task.

<figure>

![S3 Interface... a small part of it](/images/posts/how-i-backup-and-restore-data-in-my-kubernetes-persistent-volumes/03-s3-interface.png)

<figcaption align="center">S3 Interface... a small part of it</figcaption>

</figure>

It is going to be helpful for me to refactor my code to depend on some internal interface which has only the calls necessary to my code. The same refactoring will be helpful for the filesystem. At that point, I’ll be able to do have some useful unit tests for my system.

Finally, after refactoring the S3 dependency out of the project the project will be set up for exploring other backup avenues. The interface I’ll be making for S3 will consist of basic functions. Get the latest backup file path, upload file, and download file. Anything that supports these functions will fit into this solution pretty easily and it might be fun to create multiple drivers for the project to allow people to use Google Cloud, Azure, or whatever else for backups.

## In conclusion

Being able to backup and restore a system is incredibly important. I found that out the hard way. I’ve written a small docker image that helps in backing up and automatically restoring files from Kubernetes persistent volumes. You can find the image at the Docker Hub link below and the code at the GitHub repo below that.
[**Docker Hub**
*A docker image for backing up and restoring data from s3.](https://hub.docker.com/r/bloveless/s3-backup-restore)*
[**bloveless/s3-backup-restore**
*A docker image for backing up and restoring data from s3. Automatic backups to s3. Automatic restores from s3 if the…*github.com](https://github.com/bloveless/s3-backup-restore)

Thanks for reading!

## Published To
- [https://brennonloveless.medium.com/how-i-backup-and-restore-data-in-my-kubernetes-persistent-volumes-a5deec5d31ae](https://brennonloveless.medium.com/how-i-backup-and-restore-data-in-my-kubernetes-persistent-volumes-a5deec5d31ae)
