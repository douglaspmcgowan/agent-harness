/* html-ppt :: gsap-engine.js
 * Cinematic / scripted-motion engine. Opt-in, independent third engine.
 *
 * This is the heavyweight cousin of the CSS `data-anim` effects and the
 * ambient `data-fx` canvas effects. It runs choreographed GSAP timelines on
 * slide-enter, driven entirely by mood presets.
 *
 * A slide opts in with `data-gsap="<mood>"` (professional|playful|cinematic|
 * energetic). On nothing else does this engine touch the slide — decks that
 * never set `data-gsap` are completely unaffected.
 *
 * REQUIRES GSAP from CDN (add these BEFORE this script):
 *   <script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
 *   <script src="../assets/animations/gsap-engine.js"></script>
 * No GSAP plugins are needed — only core gsap (timeline + tweens). ScrollTrigger
 * is intentionally NOT used: lewislulu is keyboard-nav, one slide visible at a
 * time, no scrolling.
 *
 * Trigger mechanism mirrors fx-runtime.js exactly: a per-slide MutationObserver
 * on the `class` attribute fires on `.is-active`. Enter runs the timeline; leave
 * resets the targeted elements so re-entering replays cleanly.
 */
(function(){
  'use strict';

  /* Mood presets — adapted from the source `animateSlide` template.
   * timing/easing match the Spring-Physics + Timing-by-Mood reference tables. */
  const MOODS = {
    professional: { title:{y:40}, item:{y:20}, duration:0.5, stagger:0.06, ease:'power2.out',        overlap:'<0.2'  },
    playful:      { title:{y:40}, item:{y:24}, duration:0.7, stagger:0.10, ease:'back.out(1.7)',     overlap:'<0.2'  },
    cinematic:    { title:{y:50}, item:{y:30}, duration:1.2, stagger:0.15, ease:'power1.inOut',      overlap:'<0.25' },
    energetic:    { title:{y:30}, item:{y:20}, duration:0.4, stagger:0.08, ease:'back.out(2)',       overlap:'<0.15' }
  };

  const REDUCED = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Per-slide active timeline registry — mirrors fx-runtime's window.__hpxActive Map.
  window.__hpxGsap = window.__hpxGsap || new Map();

  /* Collect the elements a mood timeline animates on a slide.
   * Sensible defaults: the heading, then any explicitly-marked items, then a
   * fallback of common content blocks if nothing is marked. */
  function targets(slide){
    const title = slide.querySelector('h1, h2, .title, .h1, .h2');
    let items = Array.from(slide.querySelectorAll('[data-gsap-item]'));
    if (!items.length){
      // Fallback: list items, cards, and grid children — but never the title.
      // Explicitly LEAVE the other two engines alone so all three stay
      // independent: skip elements owned by the CSS engine ([data-anim]) and the
      // canvas engine ([data-fx] hosts and their children).
      items = Array.from(slide.querySelectorAll('li, .card, .grid > *'))
        .filter(el => el !== title
          && !(title && title.contains(el))
          && !(el.contains && el.contains(title))
          && !el.hasAttribute('data-anim')
          && !el.hasAttribute('data-fx')
          && !el.closest('[data-fx]'));
    }
    return { title, items };
  }

  // The runtime clones slides into `.mini-slide` wrappers for the overview /
  // presenter previews and force-sets `is-active` on them off-screen. Those are
  // not the real, visible slide — ignore them so we don't double-register.
  function isRealSlide(slide){ return !slide.closest('.mini-slide'); }

  function clearInline(el){
    if (!el) return;
    el.style.opacity = '';
    el.style.transform = '';
  }

  function runIn(slide){
    if (!isRealSlide(slide)) return;               // skip overview/presenter clones
    if (window.__hpxGsap.has(slide)) return;       // already running on this slide
    const mood = slide.getAttribute('data-gsap');
    if (!mood) return;
    const cfg = MOODS[mood] || MOODS.professional;
    const { title, items } = targets(slide);

    // Reduced motion: make everything visible immediately, run no animation.
    if (REDUCED || typeof window.gsap === 'undefined'){
      [title, ...items].forEach(clearInline);
      if (typeof window.gsap === 'undefined'){
        console.warn('[hpx-gsap] gsap not found — add the GSAP CDN <script> before gsap-engine.js. Showing slide statically.');
      }
      window.__hpxGsap.set(slide, { kill(){} });   // mark handled so we don't retry
      return;
    }

    const gsap = window.gsap;
    const tl = gsap.timeline({ defaults: { ease: cfg.ease, duration: cfg.duration } });
    if (title){
      tl.from(title, { y: cfg.title.y, opacity: 0 });
    }
    if (items.length){
      tl.from(items, { y: cfg.item.y, opacity: 0, stagger: cfg.stagger }, title ? cfg.overlap : 0);
    }
    window.__hpxGsap.set(slide, tl);
  }

  function resetIn(slide){
    const tl = window.__hpxGsap.get(slide);
    if (tl){
      try { tl.kill(); } catch(e){}
    }
    // gsap.from leaves inline styles mid-flight if interrupted — clear them so
    // the next enter starts from a clean slate (matches fx-runtime stop+reinit).
    const { title, items } = targets(slide);
    [title, ...items].forEach(clearInline);
    window.__hpxGsap.delete(slide);
  }

  // Public manual re-trigger, paralleling window.__hpxReinit for FX.
  window.__hpxGsapReplay = function(slide){
    resetIn(slide);
    runIn(slide);
  };

  function boot(){
    const slides = Array.from(document.querySelectorAll('.slide[data-gsap]')).filter(isRealSlide);
    if (!slides.length) return;

    // Run on whichever slide is already active at load.
    const active = slides.find((sl) => sl.classList.contains('is-active'));
    if (active) runIn(active);

    slides.forEach((sl) => {
      const mo = new MutationObserver((muts) => {
        for (const m of muts){
          if (m.attributeName === 'class'){
            if (sl.classList.contains('is-active')) runIn(sl);
            else resetIn(sl);
          }
        }
      });
      mo.observe(sl, { attributes: true, attributeFilter: ['class'] });
    });
  }

  if (document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
