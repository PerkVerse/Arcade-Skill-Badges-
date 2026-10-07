## GSP329 : Use Machine Learning APIs on Google Cloud: Challenge Lab

### ⚠️ Wait! Before You Copy The Code:
**Did this 1-click script save your time and effort?** 
Show some love and support my hard work by subscribing to the channel. It takes 1 second for you, but it helps me create more automated scripts daily! ❤️

```
gcloud pubsub subscriptions create pubsub-subscription-message --topic=gcloud-pubsub-topic
gcloud pubsub topics publish gcloud-pubsub-topic --message="Hello World"
```

```
gcloud pubsub subscriptions pull pubsub-subscription-message --limit 5 --auto-ack
```

```
gcloud pubsub snapshots create pubsub-snapshot --subscription=gcloud-pubsub-subscription
```

### Congratulations !!!!
