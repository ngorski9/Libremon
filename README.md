**Note:** This project is still very much a work in progress. Among other issues, I recently modified the way that actions are executed to make the system more flexible and this broke some of the animations.

# Libremon

Libremon is (will be) a tool for users to make their own monster battling games. It is being develope in the [Godot Engine](https://godotengine.org/) using GDScript, which has a very similar syntax to python.

Currently, Libremon allows users to create their own monsters, attacks, and field effects by editing CSV files. The project features an API which allows users to write moves and field effects which alter or modify any aspect of the battle. Users interact with this API by writing code snippets which are contained within the CSV files (to that end, it is recommended that one edits those CSV files using a spreadsheet program). These code snippets are written in a homebrew programming language which I created which I have called State Code. State Code is based off of JavaScript, but differs in a few ways which are specific to this project.

The game also features a rudimentary overworld system with dynamic map loading. In the future, this will ideally be more fleshed out so that users can create playable games :)

I have only included a general overview of how the system works as a preview for what is to come. Once I have a more complete release, I will add specific instructions for how to use this.

### Notable files

To see the interpretor which I wrote, go to 'standalone scripts/autoload/state code parser.gd'

The main code for the battle system is written in scenes/battle/battle.gd

## Battle API System

In a battle, there are two sides which face off. A side can have either one monster, or two. On any given turn, every monster on the field selects one move to use. When it is time for a move to be used, it executes a number of atomic **actions**. These atomic actions can include hitting the opponent, dealing damage, healing, switching out for a teammate, applying a state (see below for states) or removing states.

The way that the battle gets modified is through a system of **states**. A state is essentially any ongoing effect. For example, a state could represent the whether, a special ability that a monster has, or a lingering effect of a move on a certain monster.

States are associated with code snippits which have been written which execute at **hooks**. A hook is a certain point when something happens in the battle, the result of which can be moified by a state. There are three types of hooks:

* Menu hooks - menu hooks are triggered when the user interacts with the menu. States can hook on to menu hooks to alter the way that the user makes choices for each turn. For example, if a monster is locked into using a certain move, or is prevented from using a certain move, a menu hook would alter the player's ability to make selections in the menu.

* Value hooks - value hooks are triggered when values are calculated during the value, and states can hook onto them to alter those values. For example, a state could raise a monster's stats when they are being calculated to simulate that monster being temporarily stronger.

* Event hooks - event hooks trigger when events happen during the battle. A state can hook onto event hooks to trigger events at key points in the battle. For example, one event hook triggers at the end of each turn, so a state could cause a monster to take a small amount of damage at the end of each turn. Certain event hooks also give states the option to cancel the event which triggered the hook. For example, there is an event hook which triggers when a monster takes damage. States which hook onto that hook can prevent that damage from being dealt.

All moves are actually represented as states, as this allows moves to activate effects at various points within a turn. When the main action of a move is being used, this is actually also a hook.

When writing code for a state to hook onto a given hook, the state has access to a certain number of parameters related to the context of the present situation, such as who is being hit, whose stats are being calculated, etc. Because event hooks can trigger actions which can trigger more event hooks, and so forth, the chain of hooks currently active is stored in a stack, and this stack is also available to states when writing code in order to provide the context of the situation. States can define variables for themselves which can be referenced across code snippets, so what happens at one hook can affect another.

Currently, I have implemented 15 hooks, and I have 8 more planned.

## Planned Features

* Finish up the hook / battle system to allow the creation of moves, field effects, and special abilities with a level of complexity similar to Pokemon, or your favorite monster battling game. (Currently about 85% complete).

* A GUI interface to create and edit monsters, moves, and states, as well as animations which occur in-battle.

* An overworld system which features interaction with NPCs and allows the game creator to orchestrate cutscenes with the NPCs using state code (currently about 30% complete).

* A GUI interface to edit the overworld and orchestrate these cutscenes.

* In-game menus for inventory and parties.

* A better enemy AI system, using a look-ahead algorithm.
