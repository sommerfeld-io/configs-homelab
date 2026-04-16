# Ansible Playbook - Ollama

This Ansible playbook installs Ollama and pulls configured LLM models on all nodes in the `ollama` group. It is intended to set up and manage a local LLM inference environment across the home lab.

## What it does

- **Ollama Installation**: Installs the Ollama runtime on all targeted hosts
- **Model Deployment**: Pulls configured LLM models defined per host in the inventory

The playbook targets the `ollama` inventory group to provide a focused, repeatable setup for local LLM inference nodes in the home lab.
