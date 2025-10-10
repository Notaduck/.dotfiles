import { ActionPanel, List, Action, showHUD } from "@raycast/api";
import { useState } from "react";

const messages: Record<string, string[]> = {
  Techy: [
    "✅ Compiles on my machine. Good enough!",
    "🤖 Robot overlords say: ✅ Approved.",
    "🔧 One small PR for dev, one giant leap for prod.",
    "💻 Output: Yes. Errors: No. Merged!",
    "⌨️ Code is tighter than my Vim config.",
  ],
  Fantasy: [
    "🧙 Wizard checked your code. You're good.",
    "⚔️ Bugs vanquished. Code reigns.",
    "📜 Scroll reads: \"LGTM.\"",
    "🪄 Spell cast: merge()",
    "🐉 No dragons, only clean commits.",
  ],
  Food: [
    "🍕 Perfect slice of code.",
    "🍩 No holes in this one. Sweet!",
    "🍫 Smooth as melted chocolate.",
    "🍺 Ship it and grab a cold one.",
    "🧁 Sweet commit! Approved and baked.",
  ],
  Gamer: [
    "🎮 Boss level defeated. Approved.",
    "🕹️ GG. LGTM.",
    "💾 Saved and committed.",
    "📦 Looks like it's packaged with love.",
    "🧊 Ice cold PR. Merge it.",
  ],
  Animals: [
    "🐶 This PR is paw-some!",
    "🐱 Purrfection.",
    "🐝 Buzzing with clean code.",
    "🐢 Code that’s slow to anger, quick to run.",
    "🐙 Tentacle-tested. Merge ready.",
  ],
};

export default function Command() {
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  const handleSelect = (category: string) => {
    const options = messages[category];
    const random = options[Math.floor(Math.random() * options.length)];
    showHUD(random);
  };

  if (selectedCategory) {
    handleSelect(selectedCategory);
    setSelectedCategory(null);
  }

  return (
    <List searchBarPlaceholder="Select a category...">
      {Object.keys(messages).map((category) => (
        <List.Item
          key={category}
          title={category}
          actions={
            <ActionPanel>
              <Action title="Choose" onAction={() => setSelectedCategory(category)} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
