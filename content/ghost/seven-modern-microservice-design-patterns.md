---
title: "Seven Modern Microservice Design Patterns"
date: 2022-03-13T17:17:52-07:00
draft: false
hidden: true
---

## **Introduction**

In this post, I want to take some time to talk about some design patterns that we can use to build reliable, secure, and traceable micro-services. So, what makes these patterns different than those of monolithic applications. Applications that are distributed, in addition to having the same issues as a monolithic application, also have an entirely new set of issues due to their distributed nature.

Let's take a concrete example. Monitoring the life cycle of a request through a monolithic application is fairly simple. A few log statements here and there and you can generally follow the life of a single request but when your application is distributed... now you are responsible for tracing many requests through many micro-services that all potentially have their own identifiers and logging methodologies. So we need some sort of pattern as well as some tools to help us trace the life and, in the more interesting cases, the death of a request.

I'll be specifically talking about patterns to help with the following areas:

- Reliability
- Monitoring
- Security

I'll also discuss how products like Kong Gateway and Kong Kuma can help with those patterns.

First, what are [Kong Gateway](https://docs.konghq.com/gateway/) and [Kuma](https://kuma.io/docs/latest/)?

Well, Kong Gateway is an API Gateway. It stands in front of your API and provides additional functionality to your API. Think of [load balancing](https://docs.konghq.com/gateway/latest/reference/loadbalancing/), [token verification](https://docs.konghq.com/hub/kong-inc/jwt/), [rate limiting](https://docs.konghq.com/gateway/latest/reference/rate-limiting/), and [many other things](https://docs.konghq.com/hub/) that you as the API developer are responsible for but don't necessarily want to be responsible for building and maintaining.

Next, up is Kuma. Kuma is a service mesh. A service mesh is responsible for things like [routing](https://kuma.io/docs/latest/networking/networking/) data between your internal services, [securing that internal traffic](https://kuma.io/docs/latest/security/certificates/#data-plane-proxy-to-control-plane-communication), and providing [s](https://kuma.io/docs/1.3.1/networking/service-discovery/)[ervice discovery](https://kuma.io/docs/latest/networking/service-discovery/) between your services.

## **Reliability**

Since we now live in the micro-services world, we can no longer just check if a single server is running and if our application process is still alive. We need to implement more advanced techniques like implementing health checks and circuit breakers.

Let's talk about circuit breakers first. Circuit breakers work by analyzing the live traffic to a service to determine if the service is responding to requests appropriately. This may mean with a correct status code or within an allowed amount of time. If an instance is determined to be unhealthy then it will be removed from the service and other instances will be responsible for fulfilling requests. This pattern means that we are passively checking if a service is available and we only know that it is unavailable as it starts to fail to respond to requests.

There is another way! But it comes at a cost.

Health checks are exactly what they sound like. We need to verify that the service instances we are trying to communicate with are ready to service requests. Kong Gateway implements this by actively sending a request to each instance in a micro-service to determine if that service is up and can service the request. If an instance doesn't satisfy the health check then it will be removed from the service until it becomes healthy again. Meanwhile, requests will be routed to another healthy instance. These active requests are great for determining up time but they do generate additional load on the network and the instances, and sometimes this load is unacceptable in which case we can use circuit breakers instead.

So, we now have two ways to check up on our services. If we can afford the network load and we need to know immediately if an instance is unable to service a request then we can use a health check. If the network load is too much and we can accept a few failed live requests then we can use circuit breakers.

Kong Gateway deals specifically with ingress traffic into our application. What about traffic between our micro-services... into the realm of Kong Kuma? Well, everything we've discussed still applies to our service mesh. Kuma still tracks the health of all the internal services within its service mesh and will reroute traffic if any instances are failing either the [health check or tripping the circuit breaker](https://kuma.io/docs/latest/documentation/health/).

## **Monitoring**

Now that our services are resilient to some failures we need to look into monitoring those services. As mentioned in the intro, monitoring monolithic applications is much simpler than monitoring micro-services. First, all of our logs are in one place. We can likely query the logs from a single dashboard and use a single id in order to figure out what happened when a specific user tried to do something. In the micro-service world, we need to be able to query a single request across multiple services. For this, we need to look into distributed tracing. Both Kong Gateway and Kuma have facilities to help us in this area.

We'll look into Kong Gateway first. Kong Gateway is all about those [plugins](https://docs.konghq.com/hub/kong-inc/zipkin/)! Tracing is no exception. Kong Gateway supports adding a [Zipkin](https://zipkin.io/) plugin for capturing distributed traces. If you look into Zipkin you'll notice that the [architecture](https://zipkin.io/pages/architecture.html) is based on augmenting requests to add distributed trace ids and span ids to capture the entire request including any sub-requests that have occurred. You can read more about integrating Kong Gateway and Zipkin in this [blog post](https://konghq.com/blog/tracing-with-zipkin-in-kong-2-1-0/).

Kuma doesn't need a plugin in order to deliver request traces. Instead, it has two supported tracing collectors that can be configured. The first is Zipkin as mentioned above, and the second is [datadog](https://www.datadoghq.com/). But what does adding all this tracing actually mean.

Well, you can imagine that a request comes into your system. A request-id and span-id are generated at the gateway. Every request that originates from that request (I.E. any other micro-services that are called) will also contain that request-id and span-id as they travel through your service mesh. Finally, all those traces will be sent off to a trace aggregator of your choice so that you can go later and dig into specific requests.

Tracing can also bring to light slow down in addition to errors. Because of the distributed nature of micro-services, it can be really difficult to track down what is making a request slow. Depending on if you are using asynchronous or synchronous calls to service a request, the user may not even notice that your services are running slowly until to them it feels like something is completely broken. So having this distributed tracing in place is extremely beneficial.

Finally, the request-id can be sent back to the user so if they need to file a support ticket you'll have exactly the information you need to track down what caused the issue the user experienced.

## **Security**

There are a few types of security to deal with when we are talking about micro-services. First, is the security that everyone is aware of. That little lock icon in your browser’s location bar. The second is internal security. There are a lot of ways to manage internal micro-service security and we'll discuss two in this article: micro-segmentation and internal traffic encrypted via mTLS.

First, let's get the obvious one out of the way. One of the easiest ways to get that little lock icon in the browser’s location bar is to add a free, auto-renewing, letsencrypt certificate to Kong Gateway. The Kong Gateway plugin library will not let us down! All we need to do is install and configure the [ACME plugin](https://docs.konghq.com/hub/kong-inc/acme/) and we've got our little lock icon. Now we can move on to internal security.

What is micro-segmentation? Some of our services just don't need access nor should be allowed to access our other services. Micro-segmentation is a way for us to split our micro-services into groups or segments. We implement permissions to control which segments are allowed to speak to each other. For example, we may have a credit card processing service that is storing some sensitive data that really doesn't ever need to be contacted by the API Gateway or the outside world. Using Kuma for this micro-segmentation we can prevent inappropriate communication at the network level and secure our sensitive data by only allowing authorized services to talk to our credit card service. In Kuma, micro-segmentation is implemented as [traffic permissions](https://kuma.io/docs/latest/policies/traffic-permissions/). We specify exactly which services or groups of services, via tags, allowed traffic comes from and where that traffic is allowed to go. Keep in mind that the default TrafficPermission that Kuma installs allows traffic from all services to all services. So you'll need to make sure to configure that policy first, potentially to disallow all traffic by default, depending on how strict you want your network traffic to be.

Next, we can talk about mTLS, or mutual TLS. As a super quick primer, TLS is only used to verify the identity of the server as all clients are allowed to connect to the server. Think of a website. The clients need to verify the website but the server allows all clients regardless of their identity. Well, mutual TLS adds an additional level to this where both endpoint’s identities are verified. This makes a lot more sense in a service mesh because we don't really have servers and anonymous clients but we have peers who are talking to each other. In this case, and more specifically in the case of Kuma, mTLS is required for traffic permissions so that both endpoints can be validated before sending encrypted traffic between them. You can read more about mTLS [here](https://www.cloudflare.com/learning/access-management/what-is-mutual-tls/) as well as digging into the Kuma docs about mTLS [here](https://kuma.io/docs/latest/policies/mutual-tls/).

## **Conclusion**

In this article, I've written about a few patterns that we can use to build more reliable, traceable, and secure micro-services. More specifically, I've written about how to use Kong Gateway and Kuma to implement health checks and circuit breakers to make our micro-services more reliable. I've written about how to implement request tracing in micro-services to improve the monitorability of our micro-services. Finally, I've written about how we can implement micro-segmentation via traffic permissions in Kuma, and how Kuma can help encrypt/verify our traffic between services using mutual TLS or mTLS.

## Published To
- [https://konghq.com/blog/microservice-design-patterns/](https://konghq.com/blog/microservice-design-patterns/)
