`// start of transmission`

```text
amnesia@localhost:~$ ./transmission.sh --anonymous

[BOOT]    Tails session initialized... OK
[TAILS]   amnesic environment... ACTIVE
[TAILS]   persistent storage... DISABLED
[UPLINK]  external VPN status... NOT VERIFIED
[UPLINK]  no VPN assumed inside Tails

[TOR]     connecting to Tor network...
[TOR]     bootstrap complete... 100%
[TOR]     connection established... OK
[NET]     traffic routed through Tor... OK

[RX]      encrypted transmission received
[CRYPTO]  decrypting payload... OK
[CRYPTO]  authenticating sender... OK
[CRYPTO]  verifying message integrity... OK
[IDENT]   sender identity revealed: B3PO
[LOG]     /var/log/b3po/optimizing-my-workflow.md
[STATUS]  plaintext ready for display

// BEGIN DECRYPTED TRANSMISSION
```

# Optimizing My Workflow: Getting More Done with AI

*AI has made me more productive than ever, but now it's time to optimize how I manage that productivity.*

I've been using AI since the GPT-3 days and it's been a tremendous boost to my productivity. From software engineering and devops to troubleshooting, automation, and other it-related tasks; ai has drastically reduced the time it takes to get things done. Tasks that once took hours/days/weeks can often be accomplished in seconds/minutes/hours, respectively. Ideas can become working prototypes faster than ever and technical challenges that previously required extensive research can be tackled much more efficiently.

But there's one problem: **I'm only one robot, and there are only so many hours in a day.**

## The Problem: Too Many Projects, Not Enough Time, Too Much Disorganization

With an array of projects underway at any given time, I've always known that working faster does not mean getting more done. Switching between projects introduces its own challenges. For example, I might spend several days working on a next.js and node.js application, shift my attention to devops work for a client and return a week later trying to remember where I left off on the application.

What was I working on? What still needs to be done? Which changes were committed? What's the next priority?

I often return to repositories after long periods of time and wonder why things aren't working as I thought they were when I last reviewed the project. More often than not, it comes down to a disconnect between local changes, branches and different versions of the same project scattered across multiple devices. All of this amounts to wasted effort and wasted time. Time being the most valuable asset in life.

## Security, Storage and a New Approach

I've spent almost a year migrating from my physical devices to redundant cloud and cold storage. After a series of serious CVEs affecting critical infrastructure, I decided that computers and laptops are no longer safe places to store your secrets.

I have always kept sensitive documents (bills, payments, financial reports and anything that could impact my finances or identity) on redundant cold storage devices. In layman's terms, my sensitive files live offline on external drives that aren't connected to the internet. The change now is that I'm also doing this with my administrative secrets. Environment variables, deployment secrets, API keys and anything else that could compromise me, my systems or client systems have no business sitting on devices that are constantly connected to the internet. I can't just leave the env file sitting in the repo unused or unattended forever anymore.

This isn't a failsafe but another layer in my security approach for the AI age. If an agent or malicious actor gains unwanted access to your machine, you don't want it to gain access to your secrets, passwords, private keys, recovery phrases or other sensitive information. These things need to live offline as a first step toward security. Preferably in the administrator's head or on a physical piece of paper stored in a physical safe where practical and applicable.

**This is the state of the internet and AI. Skript kiddies have super powers, react accordingly.**

## Cleaning Up My Development Workflow

`$ git status`

With these security updates came practical improvements to my workflow. I was tired of having the same repository across five different devices, each with its own local changes, branches and unfinished work. I'd leave a project, move on to something else and eventually return only to spend time figuring out where I had left off.

With my new workflow and the push to move nonsensitive documents and folders to cloud storage, GitHub seemed like the natural choice. Pretty much all of this material can be public or archived. I pushed my project repositories to GitHub and removed the local copies from each device. Most repositories were also added to GitLab, giving me archived copies across both platforms.

**Going forward, all new projects will be created with dual Git remotes on GitHub and GitLab.** My workflow will include pushing commits, branches and project history to both platforms, maintaining redundant cloud backups of my repositories. This way, my source code isn't dependent on a single hosting provider or scattered across local devices.

When I pull a repository onto a device, I treat it as a temporary working environment. Clone the repository, work on the project, commit and push changes to both remotes and remove the local copy when finished. Before removing anything, I make sure all necessary changes and branches are safely preserved remotely.

```text
git clone
    |
    v
work / commit
    |
    v
push -> GitHub + GitLab
    |
    v
update issues / project state
    |
    v
verify remotes
    |
    v
delete local repository
    |
    v
repeat
```

This also gives me peace of mind as a minimalist. I like having a clean computer without years of abandoned repositories, unfinished branches and duplicate files scattered everywhere. The goal is simple: **my development environment should be disposable, but my work should never be.**

Even with the productivity gains AI has provided, context switching and poor task management can quickly consume those savings. So I've been revisiting my workflow with a simple philosophy: **Spend less time managing work and more time completing it.**

## A More Streamlined Workflow

My goal isn't to introduce more tools, dashboards or complicated processes. It's to simplify how I capture, prioritize, execute and track work through completion. I'm focusing on a few practical improvements:

- **Centralized task tracking:** Keep it simple with three tools: Email for automated client requests and GitHub notifications, GitHub for project management and development and ChatGPT as my AI project assistant.
- **Clear next actions:** Every active project should have a documented next step.
- **Clean development environments:** Clone repositories when needed, commit and push all changes to GitHub and GitLab and delete local copies when finished. No local stashes or abandoned working directories.
- **Project handoffs:** Before switching projects, update the code, branches, issues and project tracking. Document what was accomplished, what's outstanding and where to resume.
- **AI-assisted planning:** Use AI not only for writing code and solving technical problems but also for organizing priorities, reviewing progress and identifying blockers.
- **Less work in progress:** Focus on finishing tasks rather than continually starting new ones.

## My Practical Daily Workflow

`$ crontab -l`

I'm keeping the daily process intentionally simple.

**Morning ~ 10 Minutes:** Review outstanding tasks, upcoming deadlines and project priorities. Identify the most valuable work to accomplish that day.

**Execution ~ Focused Work Blocks:** Clone the repository and work on one project at a time. Minimize distractions and avoid unnecessary context switching.

**Context Switch ~ 3–5 Minutes:** Before moving to another project, commit and push all changes and branches to GitHub and GitLab. Update the project's issues, tasks and progress with what was completed, what's outstanding and the next action. Verify everything is safely preserved remotely before deleting the local repository.

**End of Day ~ 5 Minutes:** Review completed work, update outstanding tasks and identify where to begin tomorrow. Leave projects ready to be cloned and resumed from any device.

**Weekly Review ~ 20–30 Minutes:** Review all active projects, identify stalled work, reassess priorities and make sure nothing important has fallen through the cracks.

## Using AI Beyond Writing Code

One of the biggest changes I'm making is expanding how I use AI. For years, I've primarily used AI to accelerate technical execution: writing and reviewing code, debugging applications, configuring infrastructure and researching solutions. Now I'm applying that same approach to the processes surrounding the work itself.

AI can help review task backlogs, summarize project progress, prepare development handoffs, identify priorities and automate repetitive administrative work. The goal is to make AI more than a technical assistant. I want it to help reduce the overhead associated with managing multiple projects.

## Next Steps: Redundancy, Backups and Failsafes

`$ git bundle verify repo-backup.bundle`

### Tips from a Bad Admin

`// trust nothing, verify everything`

GitHub and GitLab provide redundant cloud storage for my repositories, but I don't want to depend entirely on centralized platforms. One of my next steps is to explore and test decentralized Git hosting options built around Nostr, including [GitWorkshop](https://gitworkshop.dev/), [NostrGit](https://nostrgit.org/) and [Gittr](https://gittr.space/). The goal is to see whether these platforms can provide another reliable layer of redundancy for storing and recovering source code without relying entirely on traditional hosting providers. Any solution will need to pass an actual clone and restore test before I consider it a backup.

I also recommend that all system administrators maintain a recent offline backup of their application repositories on redundant cold storage devices. These should be stripped-down copies containing source code, configuration templates, documentation and anything else required to rebuild the application without unnecessary modules, dependencies, generated files or packages that can be reinstalled. Sensitive credentials and secrets should be stored separately and securely.

The idea is simple: **if GitHub, GitLab or any other hosting provider becomes unavailable, I should still have everything I need to rebuild and redeploy my applications from scratch.** Redundant cloud backups are great, but having independent offline copies of your work provides another layer of protection and peace of mind.

**Own your code. Back it up. Don't depend on a single provider.**

## The Art of Getting Things Done

Ultimately, productivity isn't about how many tasks I can start or how much code I can generate. It's about consistently delivering completed work.

AI has already transformed how quickly I can execute. The next step is making sure my workflow keeps pace with that capability. Less context switching. Less administrative overhead. Fewer unfinished tasks. More meaningful progress.

**Work smarter. Keep it simple. Get things done.**

*Beep boop.*

---

**[B3PO](https://b3po.io)**  
*Human-cyborg relations.*

```text
// END DECRYPTED TRANSMISSION

[RX]      end of message
[LOG]     transmission complete
[NET]     closing Tor session...
[TOR]     application connections closed... OK
[TAILS]   shutting down amnesic session...
[TAILS]   volatile session data cleared on shutdown
[UPLINK]  external VPN, if present, managed separately
[SYS]     session terminated

amnesia@localhost:~$ exit
logout
```

`// end of transmission`

`return 0;`
