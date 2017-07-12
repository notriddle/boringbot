# An IRC bot

## Mailbot: tell it to tell someone else something, when they are next seen

    usera>      !tell userb bors is down again
    boringbot>  usera: ✔ I'll let them know
    ... five hours later ...
    userb>      I'm going to work on new features now!
    boringbot>  userb: [usera] bors is down again
    userb>      Apparently, I'm going to need to put the fires out first.

## Static responses

    usera>      !ping
    boringbot>  usera: ECHO_REPLY
    userb>      !help
    boringbot>  userb: https://github.com/bors-ng/boringbot
    userc>      !botsnack
    boringbot>  😋

## Translates GitHub issue / pull request numbers into links

    usera>      #64 is *so annoying*!
    boringbot>  Issue #64 [open]: Merging a PR does not close it, or its associated issues - https://github.com/bors-ng/bors-ng/issues/64

## Pings the channel when issues / pull requests are opened or closed

    <boringbot> Issue #64 [closed]: Merging a PR does not close it, or its associated issues - https://github.com/bors-ng/bors-ng/issues/64

## Perform arithmetic

See <https://github.com/narrowtux/abacus> for a list of supported commands.

    user> !calc 1+1
    boringbot> 2

# Copyright license

boringbot is licensed under the Apache license, version 2.0.
It should be included with the source distribution in [LICENSE-APACHE].
If it is missing, it is at <http://www.apache.org/licenses/LICENSE-2.0>.

[LICENSE-APACHE]: LICENSE-APACHE
