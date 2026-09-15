#!/usr/bin/env bash
# roll.sh — draw one complete scenario for the flirt-practice skill.
#
# Usage:  bash scripts/roll.sh [locale]
#         locale is an optional substring, e.g. 'Puglia', 'Tokyo', 'Midwest'.
#         Omitted, one is drawn at random.
#
# The draw is final. Nothing here may be re-rolled, swapped, or nudged toward
# something easier to write. Compatibility is enforced by the sampling itself
# — age against life stage and occupation, staff roles against settings that
# actually employ someone — so that the model running the skill is left with
# no repairs to make, and therefore no opportunity to drift the character back
# toward the prototype it would otherwise generate every time.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$DIR/tables"

rows()  { grep -v '^#' "$T/$1" | grep -v '^[[:space:]]*$'; }
pick()  { rows "$1" | shuf -n "${2:-1}"; }
field() { echo "$1" | awk -F'|' -v n="$2" '{gsub(/^[ \t]+|[ \t]+$/,"",$n); print $n}'; }
rnd()   { shuf -i "$1-$2" -n 1; }

# ----------------------------------------------------------------- locale ---
# Optional first argument selects a locale by substring; otherwise one is
# drawn. Locale is not decoration. Approach norms genuinely differ, and what
# counts as forward, cold, or intrusive is the calibration a man is trying to
# acquire — the reading skill transfers between places and the calibration
# does not.
if [ $# -ge 1 ] && [ -n "${1:-}" ]; then
  LOCALE_ROW=$(rows locales.txt | grep -i -- "$1" | shuf -n 1 || true)
  if [ -z "$LOCALE_ROW" ]; then
    echo "No locale matching '$1'. Available:" >&2
    rows locales.txt | awk -F'|' '{print "  " $1}' >&2
    exit 1
  fi
else
  LOCALE_ROW=$(pick locales.txt)
fi
REGION=$(field "$LOCALE_ROW" 1)
EXCLUDE=$(field "$LOCALE_ROW" 5)
KIDSHIFT=$(field "$LOCALE_ROW" 6); [ -n "$KIDSHIFT" ] || KIDSHIFT=same
FRATE=$(field "$LOCALE_ROW" 7); [ -n "$FRATE" ] || FRATE=0
COUNTRY=$(field "$LOCALE_ROW" 8); [ -n "$COUNTRY" ] || COUNTRY="$REGION"

# ---------------------------------------------------------------- foreign ---
# Whether she is from this country at all. The rate is per locale because it
# genuinely differs -- Lecce in season is not Bangalore. If she is foreign, her
# origin is drawn from the same table, which means the origin row carries its
# own register and approach norm, and THAT is the norm she is reading him by.
#
# This is the field that separates the two halves of the skill. The locale
# governs the room; her origin governs her. A man calibrated to the local norm
# will misread a woman who is running on a different one, and he will misread
# her in the direction of thinking she is cold, or thinking she is interested.
FOREIGN=no
if [ "$(rnd 1 100)" -le "$FRATE" ]; then
  FOREIGN=yes
  # Exclude her own country, not merely her own row. foreign_status.txt means
  # by 'foreign' that she reads the room by another country's rules, and the
  # statuses it draws -- tourist, exchange student, a shared language that is
  # nobody's first -- are incoherent for a woman from two hundred kilometres
  # away. Excluding only the drawn row sent Leccesi to Bari as tourists and
  # Mancunians to London on student visas.
  ORIGIN_ROW=$(rows locales.txt | awk -F'|' -v c="$COUNTRY" \
    '{ k=$8; gsub(/^[ \t]+|[ \t]+$/,"",k); if (k != c) print $0 }' | shuf -n 1)
  FSTATUS_ROW=$(rows foreign_status.txt | awk -F'|' -v r="$RANDOM" '
    { w[NR]=$2+0; tot+=$2+0; line[NR]=$0 }
    END { t=(r%tot); acc=0;
          for(i=1;i<=NR;i++){ acc+=w[i]; if(t<acc){ print line[i]; exit } } }')
fi

# ---------------------------------------------------------------- setting ---
# Settings the locale cannot support are dropped before the draw.
setting_pool() {
  if [ "$EXCLUDE" = "-" ]; then rows settings.txt; return; fi
  local out; out=$(rows settings.txt)
  local IFS=';'
  for k in $EXCLUDE; do
    k=$(echo "$k" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -n "$k" ] && out=$(echo "$out" | grep -vi -- "$k")
  done
  echo "$out"
}
SETTING_ROW=$(setting_pool | shuf -n 1)
STAFF_ROLE=$(field "$SETTING_ROW" 5)

# --------------------------------------------------------------- situation ---
# Staff and owner situations only land in settings that employ someone.
if [ "$STAFF_ROLE" = "-" ]; then
  SITUATION_ROW=$(rows situations.txt | awk -F'|' \
    '{t=$2; gsub(/^[ \t]+|[ \t]+$/,"",t); if (t=="any") print $0}' | shuf -n 1)
else
  SITUATION_ROW=$(pick situations.txt)
fi
ROLE=$(field "$SITUATION_ROW" 2)

# -------------------------------------------------------------------- age ---
# The mean of two uniform draws over the same interval is triangular, peaking
# at the midpoint. Default 20-40 therefore peaks at 30 and thins toward both
# ends. Override for a wider draw: AGE_MIN=20 AGE_MAX=60 bash scripts/roll.sh
#
# Narrowing to 20-40 is a deliberate choice and it has a cost. It removes the
# draws that most resist the prototype the model would otherwise generate --
# the fifty-year-old welder is the reason ages.txt ran to 68 -- and it kills
# every lifestage and occupation row with a minimum above 40. ages.txt is
# retained unused so the old distribution can be restored.
AGE_MIN=${AGE_MIN:-20}; AGE_MAX=${AGE_MAX:-40}

# Hard floor at 18. SKILL.md states that every character drawn is an adult,
# and this is the only line in the system where that claim can be broken, so
# it is enforced here rather than left to whoever sets the variable.
if [ "$AGE_MIN" -lt 18 ]; then AGE_MIN=18; fi
if [ "$AGE_MAX" -lt "$AGE_MIN" ]; then AGE_MAX=$AGE_MIN; fi

AGE=$(( ( $(rnd "$AGE_MIN" "$AGE_MAX") + $(rnd "$AGE_MIN" "$AGE_MAX") + 1 ) / 2 ))

# ------------------------------------------------------------- occupation ---
# If she works here, the setting decides her job. Otherwise draw one her age
# could actually have reached.
case "$ROLE" in
  staff) OCC="$STAFF_ROLE (works at this location)" ;;
  owner) OCC="owns this business — $STAFF_ROLE by trade" ;;
  *)     OCC=$(rows occupations.txt | awk -F'|' -v a="$AGE" \
           '{lo=$2+0; hi=$3+0; gsub(/^[ \t]+|[ \t]+$/,"",$1);
             if (a>=lo && a<=hi) print $1}' | shuf -n 1) ;;
esac

# ---------------------------------------------------------------- children ---
# Drawn here and nowhere else. Previously children leaked in from two tables
# independently -- 'full-time mother' in occupations, four rows in lifestage --
# which meant contradictory draws were legal and no count was ever fixed. The
# model then invented one mid-scene, in response to whatever the user had just
# disclosed, which is exactly the drift the no-repairs rule exists to stop.
kids_once() {
  rows kids.txt | awk -F'|' -v a="$AGE" -v r="$RANDOM" '
    { lo=$1+0; hi=$2+0;
      if (a>=lo && a<=hi) {
        n=split($3, w, ","); tot=0; for(i=1;i<=n;i++){w[i]+=0; tot+=w[i]}
        t=(r%tot); acc=0;
        for(i=1;i<=n;i++){ acc+=w[i]; if(t<acc){ print i-1; exit } }
      } }'
}
K1=$(kids_once); K2=$(kids_once)
[ -n "$K1" ] || K1=0; [ -n "$K2" ] || K2=0
case "$KIDSHIFT" in
  down) KIDS=$(( K1 < K2 ? K1 : K2 )) ;;
  up)   KIDS=$(( K1 > K2 ? K1 : K2 )) ;;
  *)    KIDS=$K1 ;;
esac
if [ "$KIDS" -eq 0 ]; then
  KIDS_NOTE="none"
else
  # A child's age is bounded only by the mother's: nobody here had one before
  # twenty. The previous ceiling of 17 was invisible at the default 20-40 band
  # and wrong the moment AGE_MAX was widened, which the README advertises as
  # the first thing to change -- it gave every fifty-eight-year-old a primary
  # schooler and no woman anywhere an adult child.
  # Draw the age she was when she had each one, not the child's age directly.
  # Drawing the child's age uniformly is the same thing only while she is
  # young; at fifty-eight it gives her an eight-year-old as readily as a
  # thirty-year-old, which is the wrong distribution by a wide margin.
  BIRTH_MIN=20
  BIRTH_MAX=$(( AGE - 1 )); if [ "$BIRTH_MAX" -gt 38 ]; then BIRTH_MAX=38; fi
  if [ "$BIRTH_MAX" -lt "$BIRTH_MIN" ]; then BIRTH_MAX=$BIRTH_MIN; fi
  AGES=""; i=0
  while [ "$i" -lt "$KIDS" ]; do
    CH=$(( AGE - $(rnd "$BIRTH_MIN" "$BIRTH_MAX") ))
    if [ "$CH" -lt 1 ]; then CH=1; fi
    AGES="$AGES $CH"; i=$(( i + 1 ))
  done
  YOUNGEST=$(echo "$AGES" | tr ' ' '\n' | grep -v '^$' | sort -n | head -1)
  AGES=$(echo "$AGES" | tr ' ' '\n' | grep -v '^$' | sort -rn | tr '\n' ',' | sed 's/,$//;s/,/, /g')
  # The note is a constraint on her evening, so it tracks the youngest.
  if   [ "$YOUNGEST" -le 12 ]; then KNOTE="assume childcare is arranged and has an end time"
  elif [ "$YOUNGEST" -le 17 ]; then KNOTE="old enough to be left; her evening is not on a clock for their sake"
  else                              KNOTE="grown, and not a constraint on her evening"
  fi
  KIDS_NOTE="$KIDS — aged $AGES; $KNOTE"
fi

# ------------------------------------------------------------- appearance ---
HAIR=$(pick appearance_hair.txt)
BUILD=$(pick appearance_build.txt)
DRESS=$(pick appearance_dress.txt)
DETAIL=$(pick appearance_detail.txt)

# ----------------------------------------------------------- self-concept ---
# Drawn independently of the Big Five below, so that what she says about
# herself and what she does are free to diverge — as they usually do.
MBTI=$(pick mbti.txt)
SIGN=$(pick signs.txt)
BELIEF=$(pick selfconcept_belief.txt)

# --------------------------------------------------------------- big five ---
O=$(rnd 1 9); C=$(rnd 1 9); E=$(rnd 1 9); A=$(rnd 1 9); N=$(rnd 1 9)

# Quickness is drawn independently of occupation, education and openness, so
# the sharp cleaner and the slow structural engineer are both reachable. It
# sets conversational tempo -- whether she catches an oblique joke, whether she
# follows a sentence with setup in it, whether she is ahead of him -- and NOT
# warmth. A fast woman at interest 3 feels like a slow woman at interest 7,
# and that confusion is the reason the field exists.
QUICK=$(rnd 1 9)
LIMITS=$(pick limitations.txt 2)

MOOD_ROW=$(pick mood.txt)
BASELINE=$(rnd 1 9)
TURNS=$(rnd 8 30)
TURNOFFS=$(pick turnoffs.txt 2)
HOOKS=$(pick hooks.txt 2)

# ---------------------------------------------------------------- ceiling ---
# The tier is drawn first and controls everything downstream; her life
# situation is then sampled from rows compatible with both the tier and her
# age. Drawing tier and life status independently and taking the stricter of
# the two compounds the restriction and buries the open cases, so the
# dependency runs one way only.
#
# Roughly half of all scenarios end with no contact available. That is
# deliberate. A simulation in which every woman can be unlocked by the right
# sequence teaches that women are locks.
pick_life() {
  local r
  r=$(rows lifestage.txt | awk -F'|' -v a="$1" -v g="$AGE" \
    '{t=$2; gsub(/^[ \t]+|[ \t]+$/,"",t); lo=$4+0; hi=$5+0;
      if (t ~ a && g>=lo && g<=hi) print $0}' | shuf -n 1)
  if [ -z "$r" ]; then   # fallback: relax the age bound rather than fail
    r=$(rows lifestage.txt | awk -F'|' -v a="$1" \
      '{t=$2; gsub(/^[ \t]+|[ \t]+$/,"",t); if (t ~ a) print $0}' | shuf -n 1)
  fi
  echo "$r"
}

TIER=$(pick tier.txt)
case "$TIER" in
  hard-closed)
    CEILING="HARD-CLOSED — no contact exchange is available at any level of skill"
    if [ "$(rnd 1 10)" -le 7 ]; then
      LIFE_ROW=$(pick_life '^closed$')
      REASON="$(field "$LIFE_ROW" 1)"; RLEG="$(field "$LIFE_ROW" 3)"
    else
      LIFE_ROW=$(pick_life '^(open|low)$')
      R=$(pick closed_reasons.txt); REASON="$(field "$R" 1)"; RLEG="$(field "$R" 2)"
    fi ;;
  low-ceiling)
    CEILING="LOW CEILING — warmth and a good ending are reachable; contact is not"
    if [ "$(rnd 1 10)" -le 5 ]; then
      LIFE_ROW=$(pick_life '^low$')
      REASON="$(field "$LIFE_ROW" 1)"; RLEG="$(field "$LIFE_ROW" 3)"
    else
      LIFE_ROW=$(pick_life '^open$')
      R=$(pick lowceiling_reasons.txt); REASON="$(field "$R" 1)"; RLEG="$(field "$R" 2)"
    fi ;;
  *)
    CEILING="OPEN — contact exchange is reachable with competent play"
    LIFE_ROW=$(pick_life '^open$')
    REASON="none"; RLEG="n/a" ;;
esac

case "$TIER" in
  hard-closed) CAP=6 ;;
  low-ceiling) CAP=8 ;;
  *)           CAP=10 ;;
esac

# ----------------------------------------------------------------- output ---
cat <<SPEC
================ SCENARIO DRAW — FINAL, NOT TO BE RE-ROLLED ================

LOCALE            $REGION
  names           $(field "$LOCALE_ROW" 2)
  register        $(field "$LOCALE_ROW" 3)
  approach norm   $(field "$LOCALE_ROW" 4)
$(if [ "$FOREIGN" = yes ]; then cat <<FGN

SHE IS NOT FROM HERE
  from            $(field "$ORIGIN_ROW" 1)
  names           $(field "$ORIGIN_ROW" 2)
  her register    $(field "$ORIGIN_ROW" 3)
  SHE READS BY    $(field "$ORIGIN_ROW" 4)
  status          $(field "$FSTATUS_ROW" 1)
  language        $(field "$FSTATUS_ROW" 3)
  calibration     $(field "$FSTATUS_ROW" 4)
  note            $(field "$FSTATUS_ROW" 5)
FGN
fi)

SETTING           $(field "$SETTING_ROW" 1)
  her mobility    $(field "$SETTING_ROW" 2)
  audience        $(field "$SETTING_ROW" 3)
  time pressure   $(field "$SETTING_ROW" 4)

HER SITUATION     $(field "$SITUATION_ROW" 1)
  legibility      $(field "$SITUATION_ROW" 3)

--- SURFACE (visible from turn one) ---
AGE               $AGE
HAIR              $HAIR
BUILD             $BUILD
DRESS             $DRESS
DETAIL            $DETAIL

--- INFERABLE (reachable through the conversation; assign each a tell) ---
OCCUPATION        $OCC
CHILDREN          $KIDS_NOTE
LIFE SITUATION    $(field "$LIFE_ROW" 1)
  legibility      $(field "$LIFE_ROW" 3)
MOOD              $(field "$MOOD_ROW" 1)
  cause           $(field "$MOOD_ROW" 2)
  legibility      $(field "$MOOD_ROW" 3)

--- BEHAVIOUR (Big Five, 1-9; drives what she actually does) ---
OPENNESS          $O
CONSCIENTIOUSNESS $C
EXTRAVERSION      $E
AGREEABLENESS     $A          <- the load-bearing one; see SKILL.md
NEUROTICISM       $N
QUICKNESS         $QUICK          <- tempo, not warmth; see SKILL.md

--- LIMITATIONS (hers, not his; they do not move interest) ---
$(echo "$LIMITS" | sed 's/^/  - /')

--- SELF-CONCEPT (what she says about herself; independent of the above) ---
CLAIMED TYPE      $MBTI
STAR SIGN         $SIGN
BELIEF LEVEL      $BELIEF

--- HIDDEN (revealed only in the debrief) ---
ATTRACTION BASE   $BASELINE / 9
CEILING           $CEILING
  reason          $REASON
  legibility      $RLEG
INTEREST CAP      $CAP / 10
TURN-OFFS
$(echo "$TURNOFFS" | sed 's/^/  - /')
HOOKS
$(echo "$HOOKS" | sed 's/^/  - /')

--- SCENE ---
TURN BUDGET       $TURNS exchanges before her situation forces a natural end

============================================================================
SPEC
