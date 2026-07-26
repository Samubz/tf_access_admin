import { createInertiaApp } from '@inertiajs/vue3'
import { createApp, DefineComponent, h } from 'vue'
import AdminLayout from "@/layouts/admin.vue"
import DefaultLayout from "@/layouts/default.vue"
import { createI18n } from 'vue-i18n'

createInertiaApp({
  // Set default page title
  // see https://inertia-rails.dev/guide/title-and-meta
  //
  // title: title => title ? `${title} - App` : 'App',

  // Disable progress bar
  //
  // see https://inertia-rails.dev/guide/progress-indicators
  // progress: false,

  resolve: (name) => {
    const pages = import.meta.glob<DefineComponent>('../pages/**/*.vue', {
      eager: true,
    })
    const page = pages[`../pages/${name}.vue`]
    if (!page) {
      console.error(`Missing Inertia page component: '${name}.vue'`)
    }

    // To use a default layout, import the Layout component
    // and use the following lines.
    // see https://inertia-rails.dev/guide/pages#default-layouts
    //
    // page.default.layout = page.default.layout || Layout

    const usesAdminLayout = name.startsWith('admin/') || name.startsWith('concierge/')

    if (page?.default && usesAdminLayout) {
      page.default.layout = page.default.layout ?? AdminLayout
    } else {
      page.default.layout = page.default.layout ?? DefaultLayout
    }

    return page
  },

  setup({ el, App, props, plugin }) {

    // Global i18n configuration
    const pageProps = props.initialPage.props as any
    const locale = pageProps.app.locale
    const translations = pageProps.app.translations || {}

    const i18n = createI18n({
      legacy: false,
      locale: locale,
      fallbackLocale: 'en',
      messages: {
        [locale]: translations,
      },
    })
    // End of global i18n configuration

    // Create the app
    createApp({ render: () => h(App, props) })
      .use(plugin)
      .use(i18n)
      .mount(el)
  },

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
    },
    future: {
      useScriptElementForInitialPage: true,
      useDataInertiaHeadAttribute: true,
      useDialogForErrorModal: true,
      preserveEqualProps: true,
    },
  },
}).catch((error) => {
  // This ensures this entrypoint is only loaded on Inertia pages
  // by checking for the presence of the root element (#app by default).
  // Feel free to remove this `catch` if you don't need it.
  if (document.getElementById("app")) {
    throw error
  } else {
    console.error(
      "Missing root element.\n\n" +
      "If you see this error, it probably means you loaded Inertia.js on non-Inertia pages.\n" +
      'Consider moving <%= vite_javascript_tag "inertia" %> to the Inertia-specific layout instead.',
    )
  }
})

