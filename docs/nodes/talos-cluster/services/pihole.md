---
hide:
  - toc
---


# Pihole

The [Pi-hole](https://docs.pi-hole.net/) is a DNS sinkhole that protects your devices from unwanted content, without installing any client-side software.

Pihole always runs on `talos-w3.fritz.box`. The DNS port is exposed directly on the node. Therefore Pihole is pinned to the `talos-w3.fritz.box`. The IP of the worker node is configured in the FritzBox as the primary DNS server.

```kroki-plantuml
@startuml

skinparam linetype ortho
skinparam backgroundColor transparent
skinparam fontColor #E2E4E9

' #85BBF0
skinparam arrowColor #E2E4E9
skinparam ArrowFontColor #E2E4E9

skinparam ComponentFontColor #E2E4E9
skinparam ComponentBorderColor #E2E4E9
skinparam ComponentBackgroundColor transparent

skinparam ControlFontColor #E2E4E9
skinparam ControlBorderColor #E2E4E9
skinparam ControlBackgroundColor transparent

skinparam NoteFontColor #E2E4E9
skinparam NoteBorderColor #E2E4E9
skinparam NoteBackgroundColor #1E2129

skinparam activity {
    'FontName Ubuntu
    FontName Roboto
}

component w3 as "talos-w3" <<Node>> {
    component pihole <<Pod>> {
        control web as "80" <<Web>>
        control dns as "53" <<DNS>>

    }

    control hostport as "53" <<HostPort>>

    component service <<Node Port>> {
        control nodeport as "30080" <<Web>>
    }
}

component FritzBox  <<Router>> {
    component cfg as "DNS Config"
}

web -[hidden]right- dns

web -left-> nodeport
dns -down-> hostport
hostport -right-> cfg

note bottom of w3: 192.168.178.112

@enduml
```
