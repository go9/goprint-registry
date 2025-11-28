const fs = require("fs");
const path = require("path");

const iconsDir = path.join(__dirname, "../../deps/heroicons/optimized");
const outputFile = path.join(__dirname, "heroicons.css");

const icons = [
  ["", "/24/outline"],
  ["-solid", "/24/solid"],
  ["-mini", "/20/solid"],
  ["-micro", "/16/solid"]
];

let css = "/* Auto-generated Heroicons CSS */\n\n";

if (fs.existsSync(iconsDir)) {
  icons.forEach(([suffix, dir]) => {
    const iconDir = path.join(iconsDir, dir);
    if (fs.existsSync(iconDir)) {
      fs.readdirSync(iconDir).forEach(file => {
        const name = path.basename(file, ".svg") + suffix;
        const fullPath = path.join(iconDir, file);
        const content = fs.readFileSync(fullPath).toString()
          .replace(/\r?\n|\r/g, "")
          .replace(/"/g, "'")
          .replace(/#/g, "%23")
          .replace(/</g, "%3C")
          .replace(/>/g, "%3E")
          .replace(/&/g, "%26");

        let size = "1.5rem"; // 24px
        if (name.endsWith("-mini")) {
          size = "1.25rem"; // 20px
        } else if (name.endsWith("-micro")) {
          size = "1rem"; // 16px
        }

        css += `.hero-${name} {\n`;
        css += `  --hero-${name}: url("data:image/svg+xml,${content}");\n`;
        css += `  -webkit-mask: var(--hero-${name});\n`;
        css += `  mask: var(--hero-${name});\n`;
        css += `  mask-repeat: no-repeat;\n`;
        css += `  background-color: currentColor;\n`;
        css += `  vertical-align: middle;\n`;
        css += `  display: inline-block;\n`;
        css += `  width: ${size};\n`;
        css += `  height: ${size};\n`;
        css += `}\n\n`;
      });
    }
  });

  fs.writeFileSync(outputFile, css);
  console.log(`Generated ${outputFile} with heroicons CSS`);
} else {
  console.error("Heroicons directory not found at:", iconsDir);
  process.exit(1);
}
