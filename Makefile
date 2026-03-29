CLAUDE_SKILLS := $(HOME)/.claude/skills
SKILL_DIRS := $(shell find . -maxdepth 1 -mindepth 1 -type d -not -name '.*' | sed 's|^\./||')

.PHONY: install pull

## install: repo → ~/.claude/skills  (deploy local changes)
install:
	@for skill in $(SKILL_DIRS); do \
		echo "→ installing $$skill"; \
		rsync -a --delete $$skill/ $(CLAUDE_SKILLS)/$$skill/; \
	done

## pull: ~/.claude/skills → repo  (capture changes made outside the repo)
pull:
	@for skill in $(SKILL_DIRS); do \
		echo "← pulling $$skill"; \
		rsync -a --delete $(CLAUDE_SKILLS)/$$skill/ $$skill/; \
	done
