// static/admin/js/app.js

// Ortak API yardımcı fonksiyonu: token ekler, 401'de login'e yollar
async function api(path, options = {}) {
  const token = localStorage.getItem('token');
  if (!token) {
    window.location.replace('/static/admin/login.html');
    throw new Error('no token');
  }
  options.headers = { ...(options.headers || {}), Authorization: 'Bearer ' + token };
  const res = await fetch(path, options);
  if (res.status === 401) {
    localStorage.removeItem('token');
    window.location.replace('/static/admin/login.html');
    throw new Error('unauthorized');
  }
  return res;
}

function app(){
  return {
    isDark: localStorage.getItem('theme')==='dark',
    loading: false,
    books: [],
    user: null,

    // Ekle modal state
    add: { open: false },

    // GENİŞ form
    form: {
      title:'', author:'', total_pages:0,
      cover_url:'', category:'',
      started_at:'', is_finished:false, finished_at:'',
      current_page:0, notes:'', favorite:false, tags:''
    },

    // Edit modal state
    edit: {
      open: false,
      id: null,
      model: {
        title:'', author:'', total_pages:0,
        cover_url:'', category:'',
        started_at:'', is_finished:false, finished_at:'',
        current_page:0, notes:'', favorite:false, tags:''
      }
    },

    async init(){
      document.documentElement.classList.toggle('dark', this.isDark);
      try{
        await this.fetchMe();
        await this.fetchBooks();
      }catch(e){}
    },

    toggleTheme(){
      this.isDark = !this.isDark;
      document.documentElement.classList.toggle('dark', this.isDark);
      localStorage.setItem('theme', this.isDark?'dark':'light');
    },

    async fetchMe(){
      const r = await api('/api/auth/me');
      if(!r.ok) throw new Error('Auth me alınamadı');
      this.user = await r.json();
    },

    async fetchBooks(){
      this.loading = true;
      try{
        const r = await api('/api/books');
        if(!r.ok) throw new Error('Liste alınamadı');
        this.books = await r.json();
      }catch(e){ this.toast(e.message,'error'); }
      finally{ this.loading = false; }
    },

    progressText(b){
      const tp = Number(b.total_pages||0), cp = Number(b.current_page||0);
      const pct = tp>0 ? Math.round((cp/tp)*100) : 0;
      const label = b.is_finished ? 'Bitti' : `${cp}/${tp} (${pct}%)`;
      const dates = [
        b.started_at ? `Başlangıç: ${b.started_at}` : null,
        b.finished_at ? `Bitiş: ${b.finished_at}` : null
      ].filter(Boolean).join(' • ');
      return dates ? `${label} • ${dates}` : label;
    },

    // --- ADD MODAL ---
    openAdd(){ this.add.open = true; },
    closeAdd(){ this.add.open = false; },

    async createBook(){
      const title = (this.form.title||'').trim();
      const total_pages = Number(this.form.total_pages||0);
      if(!title) return this.toast('Başlık gerekli','error');
      if(total_pages <= 0) return this.toast('Toplam sayfa 1+ olmalı','error');

      const payload = {
        title,
        author: this.form.author?.trim() || null,
        total_pages,
        cover_url: this.form.cover_url?.trim() || null,
        category: this.form.category?.trim() || null,
        started_at: this.form.started_at || null,
        finished_at: this.form.finished_at || null,
        is_finished: !!this.form.is_finished,
        current_page: Number(this.form.current_page||0),
        notes: this.form.notes?.trim() || null,
        favorite: !!this.form.favorite,
        tags: this.form.tags?.trim() || null
      };

      try{
        const r = await api('/api/books', {
          method:'POST',
          headers:{'Content-Type':'application/json'},
          body: JSON.stringify(payload)
        });
        if(!r.ok){
          const txt = await r.text();
          throw new Error(txt || 'Eklenemedi');
        }
        // reset
        this.form = {
          title:'', author:'', total_pages:0,
          cover_url:'', category:'',
          started_at:'', is_finished:false, finished_at:'',
          current_page:0, notes:'', favorite:false, tags:''
        };
        this.closeAdd();
        await this.fetchBooks();
        this.toast('Kitap eklendi');
      }catch(e){ this.toast(e.message,'error'); }
    },

    // Favori toggle
    async toggleFavorite(b){
      try{
        const r = await api(`/api/books/${b.id}`, {
          method:'PUT',
          headers:{'Content-Type':'application/json'},
          body: JSON.stringify({ favorite: !b.favorite })
        });
        if(!r.ok) throw new Error('Favori güncellenemedi');
        b.favorite = !b.favorite; // optimistic
      }catch(e){ this.toast(e.message,'error'); }
    },

    // --- EDIT MODAL ---
    openEdit(b){
      this.edit.open = true;
      this.edit.id = b.id;
      this.edit.model = {
        title: b.title || '',
        author: b.author || '',
        total_pages: Number(b.total_pages||0),
        cover_url: b.cover_url || '',
        category: b.category || '',
        started_at: b.started_at || '',
        is_finished: !!b.is_finished,
        finished_at: b.finished_at || '',
        current_page: Number(b.current_page||0),
        notes: b.notes || '',
        favorite: !!b.favorite,
        tags: b.tags || ''
      };
    },
    closeEdit(){
      this.edit.open = false;
      this.edit.id = null;
    },
    async saveEdit(){
      const m = this.edit.model;
      if(!m.title.trim()){ this.toast('Başlık gerekli','error'); return; }
      if(Number(m.total_pages||0) <= 0){ this.toast('Toplam sayfa 1+ olmalı','error'); return; }
      if(Number(m.current_page||0) > Number(m.total_pages||0)){ this.toast('Şu anki sayfa toplamdan büyük olamaz','error'); return; }

      const payload = {
        title: m.title.trim(),
        author: m.author?.trim() || null,
        total_pages: Number(m.total_pages||0),
        cover_url: m.cover_url?.trim() || null,
        category: m.category?.trim() || null,
        started_at: m.started_at || null,
        finished_at: m.finished_at || null,
        is_finished: !!m.is_finished,
        current_page: Number(m.current_page||0),
        notes: m.notes?.trim() || null,
        favorite: !!m.favorite,
        tags: m.tags?.trim() || null
      };

      try{
        const r = await api(`/api/books/${this.edit.id}`, {
          method:'PUT',
          headers:{'Content-Type':'application/json'},
          body: JSON.stringify(payload)
        });
        if(!r.ok){
          const txt = await r.text();
          throw new Error(txt || 'Güncellenemedi');
        }
        this.toast('Güncellendi');
        this.closeEdit();
        await this.fetchBooks();
      }catch(e){ this.toast(e.message,'error'); }
    },

    async removeBook(b){
      if(!confirm('Silinsin mi?')) return;
      try{
        const r = await api(`/api/books/${b.id}`, { method:'DELETE' });
        if(r.ok){ this.toast('Silindi'); this.fetchBooks(); }
        else { this.toast('Silinemedi','error'); }
      }catch(e){ this.toast(e.message,'error'); }
    },

    logout(){
      localStorage.removeItem('token');
      window.location.replace('/static/admin/login.html');
    },

    toast(msg, type='ok'){
      const root = document.getElementById('toast-root');
      const el = document.createElement('div');
      el.className = `toast ${type==='error'?'toast-error':'toast-ok'}`;
      el.textContent = msg;
      root.appendChild(el);
      setTimeout(()=>{ el.classList.add('hide'); setTimeout(()=>el.remove(),200); }, 1800);
    }
  }
}
