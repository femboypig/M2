(function () {
  const generatedAt = document.getElementById("generated-at");
  if (generatedAt) {
    const formatted = new Intl.DateTimeFormat("en-US", {
      dateStyle: "long",
      timeStyle: "short"
    }).format(new Date());
    generatedAt.textContent = "Generated: " + formatted;
  }

  const page = window.location.pathname.split("/").pop() || "index.html";
  document.querySelectorAll(".top-nav a[data-nav]").forEach((link) => {
    const target = link.getAttribute("data-nav");
    link.classList.toggle("active-link", target === page);
  });

  const navToggle = document.querySelector("[data-nav-toggle]");
  const siteNav = document.querySelector("[data-site-nav]");
  if (navToggle && siteNav) {
    navToggle.addEventListener("click", () => {
      const open = siteNav.classList.toggle("is-open");
      navToggle.setAttribute("aria-expanded", String(open));
    });
  }

  const copyButtons = document.querySelectorAll(".copy-btn[data-copy]");
  copyButtons.forEach((button) => {
    button.addEventListener("click", async () => {
      const value = button.getAttribute("data-copy") || "";
      if (!value) {
        return;
      }

      let copied = false;
      if (navigator.clipboard && window.isSecureContext) {
        try {
          await navigator.clipboard.writeText(value);
          copied = true;
        } catch (error) {
          copied = false;
        }
      }

      if (!copied) {
        const area = document.createElement("textarea");
        area.value = value;
        area.setAttribute("readonly", "readonly");
        area.style.position = "fixed";
        area.style.opacity = "0";
        document.body.appendChild(area);
        area.select();
        copied = document.execCommand("copy");
        document.body.removeChild(area);
      }

      if (!copied) {
        return;
      }

      const prev = button.textContent;
      button.textContent = "Copied";
      button.classList.add("done");
      window.setTimeout(() => {
        button.textContent = prev;
        button.classList.remove("done");
      }, 1100);
    });
  });

  const tocLinks = Array.from(document.querySelectorAll(".toc a[href^='#']"));
  const observed = tocLinks
    .map((link) => {
      const target = document.querySelector(link.getAttribute("href"));
      return target ? { link, target } : null;
    })
    .filter(Boolean);

  if (observed.length > 0) {
    const setActive = (id) => {
      tocLinks.forEach((link) => {
        link.classList.toggle("active", link.getAttribute("href") === "#" + id);
      });
    };

    const obs = new IntersectionObserver((entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio);
      if (visible[0]) {
        setActive(visible[0].target.id);
      }
    }, {
      threshold: [0.2, 0.4, 0.6],
      rootMargin: "-14% 0px -58% 0px"
    });

    observed.forEach((entry) => obs.observe(entry.target));
    setActive(observed[0].target.id);
  }
})();
