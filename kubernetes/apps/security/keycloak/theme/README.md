# Keycloak Custom Red Hat Theme

This directory contains a custom Keycloak theme with Red Hat portal styling.

## Directory Structure

```
custom-redhat/
└── login/
    ├── theme.properties           # Theme configuration
    ├── resources/
    │   ├── css/custom.css         # Red Hat styling
    │   └── img/                   # Images (logo, favicon)
    └── messages/                   # i18n translations (optional)
```

## Adding Custom Logo

1. Add your logo image to `custom-redhat/login/resources/img/`:
   - `logo.png` - Recommended size: 200x50px, transparent PNG
   - `favicon.ico` - Standard 16x16 or 32x32 favicon

2. If you don't add custom images, the default Keycloak branding will be used.

## Building the Theme

### Prerequisites

- Docker installed and running
- Authenticated to GitHub Container Registry:
  ```bash
  echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
  ```

### Build and Push

```bash
cd kubernetes/apps/security/keycloak/theme/
./build.sh
```

This will:
1. Build a Docker image with the theme files
2. Tag it as `ghcr.io/trosvald/keycloak-theme:1.0.0` and `:latest`
3. Push to GitHub Container Registry

## Testing Locally

To test the theme without building:

```bash
# Run Keycloak locally with the theme mounted
docker run -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  -v $(pwd)/custom-redhat:/opt/keycloak/themes/custom-redhat \
  quay.io/keycloak/keycloak:26.0.4 \
  start-dev
```

Then access http://localhost:8080 and check the login page.

## Customization

### Colors

Edit `resources/css/custom.css` and modify the CSS variables:

```css
:root {
  --rh-red: #EE0000;          /* Primary color */
  --rh-red-dark: #A30000;     /* Hover state */
  --rh-black: #151515;        /* Header/footer */
}
```

### Messages

Add custom text by creating `messages/messages_en.properties`:

```properties
loginTitle=Sign In to Your Organization
doLogIn=SIGN IN
```

## Deployment

The theme is automatically deployed via the Keycloak CR init container in:
`kubernetes/apps/security/keycloak/app/keycloak.yaml`
