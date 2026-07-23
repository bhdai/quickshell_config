import { readFileSync } from "node:fs";

// Evaluate in Node's host realm so returned objects use the same prototypes as assertions.
export function loadQmlJs(path, names) {
    const src = readFileSync(path, "utf8").replace(/^\s*\.pragma .*$/gm, "");
    return new Function(`${src}\n; return { ${names.join(", ")} };`)();
}
