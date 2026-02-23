(function () {
  const generatedAt = document.getElementById("generated-at");
  if (generatedAt) {
    const formatted = new Intl.DateTimeFormat("en-US", {
      dateStyle: "long",
      timeStyle: "short"
    }).format(new Date());
    generatedAt.textContent = "Created: " + formatted;
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
        const helper = document.createElement("textarea");
        helper.value = value;
        helper.setAttribute("readonly", "readonly");
        helper.style.position = "fixed";
        helper.style.opacity = "0";
        document.body.appendChild(helper);
        helper.select();
        copied = document.execCommand("copy");
        document.body.removeChild(helper);
      }

      if (!copied) {
        return;
      }

      const previous = button.textContent;
      button.textContent = "Copied";
      button.classList.add("done");
      window.setTimeout(() => {
        button.textContent = previous;
        button.classList.remove("done");
      }, 1200);
    });
  });

  const navLinks = Array.from(document.querySelectorAll(".toc a[href^='#']"));
  const sections = navLinks
    .map((link) => {
      const target = document.querySelector(link.getAttribute("href"));
      return target ? { link, target } : null;
    })
    .filter(Boolean);

  if (sections.length === 0) {
    return;
  }

  function setActive(id) {
    navLinks.forEach((link) => {
      const active = link.getAttribute("href") === "#" + id;
      link.classList.toggle("active", active);
    });
  }

  const sectionObserver = new IntersectionObserver((entries) => {
    const visible = entries
      .filter((entry) => entry.isIntersecting)
      .sort((a, b) => b.intersectionRatio - a.intersectionRatio);

    if (visible.length > 0) {
      setActive(visible[0].target.id);
    }
  }, {
    threshold: [0.25, 0.45, 0.65],
    rootMargin: "-12% 0px -55% 0px"
  });

  sections.forEach((item) => sectionObserver.observe(item.target));

  const first = sections[0];
  if (first && first.target) {
    setActive(first.target.id);
  }
})();
