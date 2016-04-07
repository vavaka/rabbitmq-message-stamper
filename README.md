# RabbitMQ Message Stamper Plugin #

This plugin injects `origin` and `timestamp` headers of a message as it enters
RabbitMQ with the routed node name and current node time.

## Supported RabbitMQ Versions ##

This plugin targets RabbitMQ 3.6.0 and later versions.

## Installing ##

Clone the repo and then build it with `make`:

```
cd rabbitmq-message-stamper
make
# [snip]
make dist
# [snip]
ls plugins/*
```

Build artefacts then can be found under the `plugins` directory.

Finally copy `plugins/rabbitmq_message_stamper.ez` to the `$RABBITMQ_HOME/plugins` folder.

## Usage ##

Just enable the plugin with the following command:

```bash
rabbitmq-plugins enable rabbitmq_message_stamper
```

The plugin will then hook into the `basic.publish` process in order to
inject `origin` and `timestamp` headers.

## Configuration ##
By default plugin is applyed to all exchanges.
You can specify exchanges you want pluging be applied to in RabbitMQ configuration file:
```
[
    ...

    {rabbitmq_message_stamper, [
        {timestamp, [<<"exchange1">>, <<"exchange2">>]},
        {origin, [<<"echange1">>]}
    ]}
].

```

## Limitations ##

The plugin hooks into the basic.publish path, so expect a small throughput reduction when using this plugin,
since it has to modify every message that crosses RabbitMQ.

## LICENSE ##

See the LICENSE file
