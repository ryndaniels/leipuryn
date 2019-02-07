## Leipuryn

Leipuryn `(/'laɪ̯purin/)` bakes images for Raspberry Pis. It is currently **VERY MUCH A WORK IN PROGRESS**
and just changes wildly all the time.

This `README` will get better over time, I promise.

### Why?

If you have to ask, you probably aren't one of the two people who cares about this project.

### Leipuryn Components

Leipuryn consists of two parts:

* `leipuryn.go`, which downloads and unzips the latest lite raspbian image, and
* `raparperyn.sh`, which mounts the image, makes the desired modifications to it, and then creates a new ISO to be uploaded.

Yes, I realize that `leipuryn` could be replaced with a few lines of bash. That wasn't the point here.

### Running Leipuryn

Leipuryn really isn't designed to be run manually. It is designed to be triggered and run as part of an automated process, whenever changes are pushed to the (private) `ryngredients` repo. Because it mounts a linux image as part of the image build process, it wants to be run on a linux system; since neither of the two people who care about this project develop on linux boxes, it's currently designed to be run on a linux Travis CI build.
