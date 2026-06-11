/** Плавный скролл к якорю (не включает scroll-behavior на всей странице — меньше фризов). */
export function scrollToId(id: string) {
  const target = document.getElementById(id);
  if (!target) return;

  target.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

/** Скролл с учётом hash после перехода на главную. */
export function scrollToHash(hash: string) {
  const id = hash.replace(/^#/, '');
  if (!id) return;
  requestAnimationFrame(() => scrollToId(id));
}
