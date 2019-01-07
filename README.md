## Leipuryn

Leipuryn `(/'laɪ̯purin/)` bakes images for Raspberry Pis.

This `README` will get better over time, I promise.

### Building Leipuryn

You should just be able to run `go build`. If you want to do some fun cross-platform stuff (such as)
building a windows exe from an osx box, you can use env vars: `env GOOS=windows GOARCH=amd64 go build`.

### Running Leipuryn

* To build an image from whatever latest raspbian image is available for download,
run with no arguments: `./leipuryn`
* To build an image downloaded from a different url: `./leipuryn -url [YOUR_URL]`
* To build an image based on an image you already have locally: `./leipuryn -path [FULL_PATH_TO_IMG_FILE]`

### Why?

If you have to ask, you probably aren't one of the two people who cares about this project.
